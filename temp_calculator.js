// 크라운 체크박스 토글
document.getElementById('crown-check').addEventListener('change', function() {
    const crownInput = document.getElementById('crown-input-div');
    if (this.checked) {
        crownInput.classList.add('active');
    } else {
        crownInput.classList.remove('active');
    }
});

function calculate() {
    // 입력값 가져오기
    const reverberioBase = parseFloat(document.getElementById('reverberio-base').value) || 0;
    const reverberioEquipment = parseFloat(document.getElementById('reverberio-equipment').value) || 0;
    const blacklotusBase = parseFloat(document.getElementById('blacklotus-base').value) || 0;
    const blacklotusEquipment = parseFloat(document.getElementById('blacklotus-equipment').value) || 0;
    
    const useRita = document.getElementById('rita-check').checked;
    const useCrown = document.getElementById('crown-check').checked;
    const crownAttack = parseFloat(document.getElementById('crown-attack').value) || 0;

    // 유효성 검사
    if (reverberioBase === 0 || blacklotusBase === 0) {
        alert('값 입력 ㄱㄱ');
        return;
    }

    if (useCrown && crownAttack === 0) {
        alert('크라운 체크했으면 크라운 공격력 입력 ㄱㄱ');
        return;
    }

    // 고정 스킬 공증 수치
    const reverberioSkillBonus = 160; // %
    const blacklotusSkillBonus = 115.12; // %

    // 리타 공증
    const ritaBonus = useRita ? 80.42 : 0; // %

    // 리버렐리오 최종 공격력 계산
    let reverberioFinal = reverberioBase * (1 + (reverberioEquipment + reverberioSkillBonus + ritaBonus) / 100);

    // 흑련 최종 공격력 계산
    let blacklotusFinal = blacklotusBase * (1 + (blacklotusEquipment + blacklotusSkillBonus + ritaBonus) / 100);
    if (useCrown) {
        blacklotusFinal += crownAttack * 0.6451; // 크라운 버프 64.51%
    }

    // 결과 표시
    document.getElementById('reverberio-final').textContent = reverberioFinal.toFixed(2);
    document.getElementById('blacklotus-final').textContent = blacklotusFinal.toFixed(2);

    // 승자 결정
    const winnerText = document.getElementById('winner-text');
    if (reverberioFinal < blacklotusFinal) {
        //  필요 옵작 수치 계산
        const fixedBonus = reverberioSkillBonus + ritaBonus; // 160 + 리타보너스
        const needOverload = ((blacklotusFinal / reverberioBase) - 1) * 100 - fixedBonus;

        winnerText.innerHTML = `<strong>리버렐리오</strong>가 먹음<br><br>` +
            `리버렐리오 필요 옵작 : <strong>${needOverload.toFixed(2)}%</strong> <br>참고로 옵작 공증 최대치가 58.52%임. 각 안나오면 돈쓰래`;
    } else if (reverberioFinal > blacklotusFinal) {
        winnerText.innerHTML = '<strong>흑련</strong>이 먹음';
    } else {
        winnerText.innerHTML = '똑같아서 나도 몰?루';
    }

    // 결과 영역 표시
    document.getElementById('result').classList.add('show');
}

// Enter 키로도 계산 가능하도록
document.addEventListener('keypress', function(e) {
    if (e.key === 'Enter') {
        calculate();
    }

});
