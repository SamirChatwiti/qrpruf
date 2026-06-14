class GharadOption {
  const GharadOption({
    required this.title,
    required this.description,
    this.autoFields,
    this.reportTemplate,
    this.iconPath,
  });

  final String title;
  final String description;
  final String? autoFields;
  final String? reportTemplate;
  final String? iconPath;
}

const List<GharadOption> priveGharadOptions = [
  GharadOption(
    title: 'توثيق قرار إداري أو تدبيري داخلي',
    description:
        'لتوثيق اتخاذ قرار داخلي، إداري أو تدبيري، صادر عن الإدارة أو الأجهزة المسؤولة داخل المؤسسة',
    iconPath: 'assets/images/huissier/User board.svg',
  ),
  GharadOption(
    title: 'توثيق إبرام عقد أو اتفاق',
    description:
        'لتوثيق إبرام عقد، اتفاق، أو التزام تجاري مع طرف داخلي أو خارجي',
    iconPath: 'assets/images/huissier/Give Document.svg',
  ),
  GharadOption(
    title: 'توثيق اجتماع أو مداولة داخلية',
    description: 'لتسجيل انعقاد اجتماع إداري، تقني، أو استراتيجي، مع ضبط خلاصاته وتوصياته',
    iconPath: 'assets/images/huissier/User board.svg',
  ),
  GharadOption(
    title: 'توثيق تسليم أو توصل بمنتجات أو خدمات',
    description: 'لإثبات تسليم أو توصل بسلع، منتجات، أو خدمات في إطار نشاط المؤسسة',
    iconPath: 'assets/images/chakhsi/Delivery hand send.svg',
  ),
  GharadOption(
    title: 'توثيق تنفيذ إجراء أو مسار عمل',
    description: 'لتوثيق تنفيذ إجراء داخلي، مسطرة تشغيلية، أو خطوة ضمن سلسلة الإنتاج أو الخدمة',
    iconPath: 'assets/images/huissier/Square message edit text.svg',
  ),
  GharadOption(
    title: 'توثيق حادثة أو خلل تشغيلي',
    description: 'لتسجيل حادثة، خلل، أو توقف في النشاط، مع بيان ظروفه وآثاره',
    iconPath: 'assets/images/huissier/Folder File Warning.svg',
  ),
  GharadOption(
    title: 'توثيق مراقبة الجودة أو المطابقة',
    description: 'لتوثيق عمليات مراقبة الجودة، المطابقة، أو التدقيق الداخلي',
    iconPath: 'assets/images/huissier/Balance.svg',
  ),
  GharadOption(
    title: 'توثيق علاقة مع زبون أو شريك',
    description: 'لتسجيل تواصل، شكاية، طلب، أو التزام متبادل مع زبون أو شريك',
    iconPath: 'assets/images/chakhsi/User checked.svg',
  ),
  GharadOption(
    title: 'توثيق لأغراض التحوّط والمسؤولية القانونية',
    description: 'لتوثيق عناصر تُستعمل لاحقاً لإثبات احترام الالتزامات القانونية، التعاقدية، أو التنظيمية',
    iconPath: 'assets/images/huissier/Balance.svg',
  ),
  GharadOption(
    title: 'معطيات أخرى أو حالات إضافية',
    description:
        'تُستعمل هذه الفقرة لإدراج أي معلومة، ظرف، أو ملاحظة ترى المؤسسة أنها مهمة، ولم تندرج ضمن الغايات أعلاه، دون أن تُعدّ هذه الإضافة توثيقاً مستقلاً أو تقريراً رسمياً في حد ذاته',
    autoFields: '• طبيعة المعطى (اختياري):\n'
        'قرار داخلي – عقد – اجتماع – تسليم – إجراء تشغيلي – حادثة – مراقبة جودة – علاقة زبون – ملاحظة مؤسسية – أخرى\n\n'
        '• مصدر المعلومة (اختياري):\n'
        'الإدارة – الموظف المختص – شريك – زبون – وثيقة داخلية – نظام معلوماتي',
    iconPath: 'assets/images/huissier/Folder File Add Plus.svg',
  ),
];
