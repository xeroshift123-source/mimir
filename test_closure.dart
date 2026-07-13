void main() {
  final Map<String, int>? map = {'test': 1};
  if (map == null) return;

  void apply() {
    print(map['test']);
  }
  apply();
}
