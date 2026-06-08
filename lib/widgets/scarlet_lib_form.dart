import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:mimir/services/database_service.dart';
import 'package:mimir/utils/cp_calculator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mimir/providers/nikke_provider.dart';
import 'package:provider/provider.dart';
import 'package:mimir/utils/blabla_map.dart';
import 'package:mimir/models/nikke.dart';
import 'package:mimir/widgets/cube_level_dialog.dart';

class ScarletLibCalculatorForm extends StatefulWidget {
  const ScarletLibCalculatorForm({super.key});

  @override
  State<ScarletLibCalculatorForm> createState() =>
      _ScarletLibCalculatorFormState();
}

class _ScarletLibCalculatorFormState extends State<ScarletLibCalculatorForm> {
  // Input Controllers
  final _libAtkController = TextEditingController(text: "10000");
  final _libOverController = TextEditingController(text: "0");
  final _scarletAtkController = TextEditingController(text: "10000");
  final _scarletOverController = TextEditingController(text: "0");

  final _crownAtkController = TextEditingController(text: "8000");
  final _ritaAtkController = TextEditingController(text: "80.42");

  bool _useRita = false;
  bool _useCrown = false;
  String? _bufferType;

  double resScarletFinal = 0;
  double resLibFinal = 0;

  String resultMessage = "수치를 입력하고 계산하기를 눌러주세요.";
  String needOverloadMessage = "";
  bool isError = false;
  final NumberFormat _formatter = NumberFormat('#,###');

  bool _isSyncing = false;

  Future<void> _handleAutoSync() async {
    setState(() => _isSyncing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final openId = prefs.getString('last_synced_openid');
      if (openId == null || openId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('동기화된 프로필이 없습니다. 블라블라링크 동기화를 먼저 진행해주세요.')),
          );
        }
        return;
      }

      final dbService = DatabaseService();
      final profile = await dbService.getCommanderProfile(openId);
      if (profile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('프로필 데이터를 불러올 수 없습니다.')),
          );
        }
        return;
      }

      final characters = profile['characters'] as List<dynamic>? ?? [];
      final recycleRoom = profile['recycleRoom'] as List<dynamic>? ?? [];
      var localNikkes = context.read<NikkeProvider>().nikkeList;
      if (localNikkes.isEmpty) {
        await context.read<NikkeProvider>().loadNikkes();
        localNikkes = context.read<NikkeProvider>().nikkeList;
      }
      final Map<String, Nikke> nikkeNameMap = {
        for (final n in localNikkes) n.name: n
      };

      Map<String, dynamic> injectConsoleLevels(Map<String, dynamic> c, Nikke? n) {
        int common = 0, classConsole = 0, companyConsole = 0;
        for (final item in recycleRoom) {
          if (item is Map) {
            final tid = item['tid'] as int? ?? 0;
            final lv = item['lv'] as int? ?? 0;
            if (tid == 1001) common = lv;
            if (n != null) {
              if (n.type == 'ATK' && tid == 1101) classConsole = lv;
              if (n.type == 'DEF' && tid == 1102) classConsole = lv;
              if (n.type == 'SUP' && tid == 1103) classConsole = lv;
              final compStr = n.company.toString().split('.').last;
              if (compStr == 'Elysion' && tid == 1201) companyConsole = lv;
              if (compStr == 'Missilis' && tid == 1202) companyConsole = lv;
              if (compStr == 'Tetra' && tid == 1203) companyConsole = lv;
              if (compStr == 'Pilgrim' && tid == 1204) companyConsole = lv;
              if (compStr == 'Abnormal' && tid == 1205) companyConsole = lv;
            }
          }
        }
        final mod = Map<String, dynamic>.from(c);
        mod['commonConsoleLevel'] = common;
        mod['classConsoleLevel'] = classConsole;
        mod['companyConsoleLevel'] = companyConsole;
        return mod;
      }

      Map<String, dynamic>? libChar;
      Map<String, dynamic>? scarletChar;
      Map<String, dynamic>? crownChar;
      
      for (final char in characters) {
        final nameCode = char['name_code'] as int? ?? 0;
        final mappedName = BlablaMap.characterNames[nameCode] ?? '';
        if (mappedName == '리버렐리오') libChar = char;
        if (mappedName == '홍련 : 흑영') scarletChar = char;
        if (mappedName == '크라운') crownChar = char;
      }

      if (libChar == null && scarletChar == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('동기화된 데이터에서 리버렐리오와 흑련을 찾을 수 없습니다.')),
          );
        }
        return;
      }

      final List<Map<String, dynamic>> dialogNikkes = [];
      if (libChar != null) {
        dialogNikkes.add({'name': '리버렐리오', 'char': libChar, 'image': 'assets/nikke/liberalio.webp'});
      }
      if (scarletChar != null) {
        dialogNikkes.add({'name': '홍련 : 흑영', 'char': scarletChar, 'image': 'assets/nikke/scarlet_black_shadow.webp'});
      }
      if (_useCrown && crownChar != null) {
        dialogNikkes.add({'name': '크라운', 'char': crownChar, 'image': 'assets/nikke/crown.webp'});
      }

      if (!mounted) return;
      final selectedCubeLevels = await showDialog<Map<String, int>>(
        context: context,
        builder: (context) => CubeLevelDialog(nikkes: dialogNikkes),
      );

      if (selectedCubeLevels == null) {
        if (mounted) setState(() => _isSyncing = false);
        return;
      }

      if (!CpCalculator.isInitialized) {
        await CpCalculator.init();
      }

      void applyCharStats(Map<String, dynamic> char, String name, TextEditingController atkCtrl, TextEditingController? overCtrl) {
        final localNikke = nikkeNameMap[name];
        final modChar = injectConsoleLevels(char, localNikke);
        final customCube = selectedCubeLevels[name] ?? 0;
        
        double atk400 = 0;
        double overAtk = 0;
        
        if (CpCalculator.isInitialized) {
          final cp = CpCalculator.calculateCp(modChar, localNikke, targetLevel: 400, assumeCube15: false, customCubeLevel: customCube);
          if (cp != -1.0) {
            final stats = CpCalculator.calculateTargetStats(modChar, localNikke, targetLevel: 400, assumeCube15: false, customCubeLevel: customCube);
            atk400 = stats['atk'] ?? 0;
          } else {
            atk400 = 0;
          }
        }
        
        if (overCtrl != null) {
          final equips = modChar['equipment'] as List<dynamic>? ?? [];
          for (final eq in equips) {
            final options = eq['overloadOptions'] as List<dynamic>? ?? [];
            for (final opt in options) {
              final int id = opt as int? ?? 0;
              if (id >= 7000801 && id <= 7000815) { // 공격력 옵션
                overAtk += BlablaMap.getOptionPercent(id);
              }
            }
          }
        }
        
        atkCtrl.text = atk400 > 0 ? _formatter.format(atk400.round()) : "0";
        if (overCtrl != null) overCtrl.text = overAtk.toStringAsFixed(2);
      }

      if (libChar != null) applyCharStats(libChar, '리버렐리오', _libAtkController, _libOverController);
      if (scarletChar != null) applyCharStats(scarletChar, '홍련 : 흑영', _scarletAtkController, _scarletOverController);
      if (_useCrown && crownChar != null) {
        applyCharStats(crownChar, '크라운', _crownAtkController, null);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('동기화된 스탯 정보를 성공적으로 불러왔습니다! 🚀')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('자동 입력 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  void dispose() {
    _scarletAtkController.dispose();
    _scarletOverController.dispose();
    _libAtkController.dispose();
    _libOverController.dispose();
    _crownAtkController.dispose();
    _ritaAtkController.dispose();
    super.dispose();
  }

  // 콤마 제거 후 파싱하는 헬퍼 함수
  double _parse(String text) => double.tryParse(text.replaceAll(',', '')) ?? 0;

  void _calculate() {
    setState(() {
      double reverberioBase = _parse(_libAtkController.text);
      double reverberioEquipment = _parse(_libOverController.text);
      double blacklotusBase = _parse(_scarletAtkController.text);
      double blacklotusEquipment = _parse(_scarletOverController.text);
      double crownAttack = _parse(_crownAtkController.text);

      if (reverberioBase == 0 || blacklotusBase == 0) {
        resultMessage = "리버렐리오와 흑련의 기본 공격력을 모두 입력해주세요.";
        isError = false;
        needOverloadMessage = "";
        return;
      }

      if (_useCrown && crownAttack == 0) {
        resultMessage = "크라운을 사용한다면 크라운 공격력을 입력해주세요.";
        isError = false;
        needOverloadMessage = "";
        return;
      }

      // 고정 스킬 공증 수치
      const double reverberioSkillBonus = 160.0; // %
      const double blacklotusSkillBonus = 115.12; // %

      // 리타 공증
      double ritaBonus = _useRita ? _parse(_ritaAtkController.text) : 0.0; // %

      // 리버렐리오 최종 공격력 계산
      resLibFinal = reverberioBase *
          (1 + (reverberioEquipment + reverberioSkillBonus + ritaBonus) / 100);

      // 흑련 최종 공격력 계산
      resScarletFinal = blacklotusBase *
          (1 + (blacklotusEquipment + blacklotusSkillBonus + ritaBonus) / 100);

      if (_useCrown) {
        resScarletFinal += crownAttack * 0.6451; // 크라운 버프 64.51%
      }

      // 승자 결정
      if (resLibFinal < resScarletFinal) {
        // 리버렐리오가 먹음 (문제 상황)
        isError = true;
        double fixedBonus = reverberioSkillBonus + ritaBonus;
        double needOverload =
            ((resScarletFinal / reverberioBase) - 1) * 100 - fixedBonus;

        resultMessage = "🚨 리버렐리오가 버프를 받습니다!";
        needOverloadMessage =
            "리버렐리오 필요 추가 옵작: ${needOverload.toStringAsFixed(2)}%";
      } else if (resLibFinal > resScarletFinal) {
        // 흑련이 먹음 (정상 상황)
        isError = false;
        double margin = resLibFinal - resScarletFinal;
        double scarletAllowedIncrease = (margin / blacklotusBase) * 100;
        double libAllowedDecrease = (margin / reverberioBase) * 100;

        resultMessage = "✅ 흑련이 버프를 받습니다!";
        needOverloadMessage = "💡 현재 상태 기준 여유 수치\n"
            "• 흑련 오버공증: ${scarletAllowedIncrease.toStringAsFixed(2)}% 더 높아도 안전합니다.\n"
            "• 리버렐리오 오버공증: ${libAllowedDecrease.toStringAsFixed(2)}% 더 낮아도 안전합니다.";
      } else {
        isError = false;
        resultMessage = "⚖️ 똑같아서 나도 몰?루";
        needOverloadMessage = "";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 24),
        _buildCharacterInputRow(
            label: "리버렐리오",
            imagePath: "assets/nikke/liberalio.webp",
            color: Colors.blue,
            atkCtrl: _libAtkController,
            overCtrl: _libOverController),
        const SizedBox(height: 16),
        _buildCharacterInputRow(
            label: "흑련",
            imagePath: "assets/nikke/scarlet_black_shadow.webp",
            color: Colors.purple,
            atkCtrl: _scarletAtkController,
            overCtrl: _scarletOverController),
        const SizedBox(height: 24),
        if (_bufferType == 'rita' || _bufferType == 'both')
          _buildBufferRow(
            label: "리타",
            imagePath: "assets/nikke/liter.webp",
            color: Colors.green,
            description: "공증 수치 적용",
            atkCtrl: _ritaAtkController,
            atkLabel: "리타 공증(%)",
          ),
        if (_bufferType == 'crown' || _bufferType == 'both')
          _buildBufferRow(
            label: "크라운",
            imagePath: "assets/nikke/crown.webp",
            color: Colors.yellow.shade700,
            description: "선흑련 첫버스트 한정 시공증 +64.51%",
            atkCtrl: _crownAtkController,
            atkLabel: "크라운 공격력",
          ),
        const SizedBox(height: 16),
        // 동기화 자동 입력 버튼
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isSyncing ? null : _handleAutoSync,
            icon: _isSyncing 
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.sync, color: Colors.white),
            label: Text(
              _isSyncing ? "동기화 정보 불러오는 중..." : "동기화 스탯 자동 입력",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildActionButtons(),
        const SizedBox(height: 20),
        _buildResultCard(),
        const SizedBox(height: 16),
        _buildStatusBox(),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(children: [
      Expanded(
          flex: 2,
          child: SizedBox(
              height: 50,
              child: ElevatedButton(
                  onPressed: _calculate,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text("계산하기",
                      style: TextStyle(fontWeight: FontWeight.bold))))),
      const SizedBox(width: 8),
      Expanded(
          flex: 1,
          child: SizedBox(
              height: 50,
              child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: PopupMenuButton<String>(
                      onSelected: (val) {
                        setState(() {
                          _bufferType = val == 'remove' ? null : val;
                          _useRita =
                              _bufferType == 'rita' || _bufferType == 'both';
                          _useCrown =
                              _bufferType == 'crown' || _bufferType == 'both';
                        });
                      },
                      itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 'rita', child: Text("리타")),
                            const PopupMenuItem(
                                value: 'crown', child: Text("크라운")),
                            const PopupMenuItem(
                                value: 'both', child: Text("리타 + 크라운")),
                            const PopupMenuItem(
                                value: 'remove',
                                child: Text("제거",
                                    style: TextStyle(color: Colors.red)))
                          ],
                      child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("버퍼 선택",
                                style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            Icon(Icons.arrow_drop_down, color: Colors.orange)
                          ]))))),
    ]);
  }

  Widget _buildBufferRow(
      {required String label,
      required String imagePath,
      required Color color,
      required String description,
      TextEditingController? atkCtrl,
      String atkLabel = "공격력"}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color, width: 2),
                image: DecorationImage(
                    image: AssetImage(imagePath), fit: BoxFit.cover))),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(description,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (atkCtrl != null) ...[
            const SizedBox(height: 6),
            _buildCompactField(atkLabel, atkCtrl)
          ]
        ])),
      ]),
    );
  }

  Widget _buildCharacterInputRow(
      {required String label,
      required String imagePath,
      required Color color,
      required TextEditingController atkCtrl,
      required TextEditingController overCtrl}) {
    return Row(children: [
      Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 2),
              image: DecorationImage(
                  image: AssetImage(imagePath), fit: BoxFit.cover))),
      const SizedBox(width: 12),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _buildCompactField("400렙 공", atkCtrl)),
          const SizedBox(width: 8),
          Expanded(child: _buildCompactField("오버공증 (%)", overCtrl))
        ])
      ])),
    ]);
  }

  Widget _buildCompactField(String label, TextEditingController controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(
            fontSize: 12, color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
            isDense: true,
            filled: true,
            fillColor: isDark ? const Color(0xFF242424) : Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: isDark
                        ? Colors.grey.shade800
                        : Colors.grey.shade300))));
  }

  Widget _buildResultCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("계산 결과",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 10),
          _resRow("리버렐리오 최종 공격력", _formatter.format(resLibFinal.toInt()),
              !isError, Colors.blue),
          const SizedBox(height: 4),
          _resRow("흑련 최종 공격력", _formatter.format(resScarletFinal.toInt()),
              isError, Colors.purple),
          const Divider(height: 20),
          Text(
              "• 리버렐리오: 오버 + 스킬보너스(160%)${_useRita ? ' + 리타(${_ritaAtkController.text}%)' : ''}",
              style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey.shade400 : Colors.grey)),
          Text(
              "• 흑련: 오버 + 스킬보너스(115.12%)${_useRita ? ' + 리타(${_ritaAtkController.text}%)' : ''}${_useCrown ? ' + 크라운버프' : ''}",
              style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey.shade400 : Colors.grey)),
        ]));
  }

  Widget _resRow(String name, String val, bool isLoser, Color charColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(name,
          style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade800)),
      Text(val,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold, color: charColor))
    ]);
  }

  Widget _buildStatusBox() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color boxColor;
    Color borderColor;
    Color textColor;
    Color detailColor;

    if (isError) {
      boxColor =
          isDark ? Colors.red.shade900.withOpacity(0.4) : Colors.red.shade50;
      borderColor = isDark ? Colors.red.shade900 : Colors.red.shade200;
      textColor = isDark ? Colors.red.shade300 : Colors.red.shade800;
      detailColor = isDark ? Colors.red.shade200 : Colors.red.shade900;
    } else {
      boxColor = isDark
          ? Colors.green.shade900.withOpacity(0.4)
          : Colors.green.shade50;
      borderColor = isDark ? Colors.green.shade900 : Colors.green.shade200;
      textColor = isDark ? Colors.green.shade300 : Colors.green.shade800;
      detailColor = isDark ? Colors.green.shade200 : Colors.green.shade900;
    }

    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: boxColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor)),
        child: Column(
          children: [
            Text(resultMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            if (needOverloadMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(needOverloadMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: detailColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ]
          ],
        ));
  }
}
