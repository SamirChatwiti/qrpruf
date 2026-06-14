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

const List<GharadOption> jamiyateGharadOptions = [
  GharadOption(
    title: 'توثيق قرار صادر عن جهاز مسيّر',
    description: 'لتوثيق قرار صادر عن مجلس، مكتب، لجنة، أو جهاز مسيّر تابع للهيئة أو الجمعية',
    iconPath: 'assets/images/huissier/User board.svg',
  ),
  GharadOption(
    title: 'توثيق اجتماع أو جمع عام',
    description: 'لتسجيل انعقاد اجتماع، مجلس، أو جمع عام عادي أو استثنائي، مع ضبط الحضور والمخرجات',
    iconPath: 'assets/images/huissier/User board.svg',
  ),
  GharadOption(
    title: 'توثيق نشاط مهني أو جمعوي',
    description: 'لتوثيق تنظيم نشاط، ندوة، دورة تكوينية، أو مبادرة ذات طابع مهني أو اجتماعي',
    iconPath: 'assets/images/huissier/Square message edit text.svg',
  ),
  GharadOption(
    title: 'توثيق مراسلة أو تواصل مؤسسي',
    description: 'لتسجيل مراسلة رسمية، بيان، أو تواصل صادر أو وارد باسم الهيئة أو الجمعية',
    iconPath: 'assets/images/huissier/Send Document.svg',
  ),
  GharadOption(
    title: 'توثيق شراكة أو اتفاق تعاون',
    description: 'لتوثيق إبرام شراكة، بروتوكول تعاون، أو اتفاق مع جهة عمومية أو خاصة',
    iconPath: 'assets/images/huissier/Give Document.svg',
  ),
  GharadOption(
    title: 'توثيق تدبير مالي أو محاسبي',
    description: 'لتسجيل عملية مالية، مصادقة على ميزانية، أو صرف مرتبط بأنشطة الهيئة أو الجمعية',
    iconPath: 'assets/images/huissier/Give Document.svg',
  ),
  GharadOption(
    title: 'توثيق إجراء تنظيمي أو داخلي',
    description: 'لتوثيق اعتماد نظام داخلي، تعديل قانون أساسي، أو إجراء تنظيمي',
    iconPath: 'assets/images/huissier/Square message edit text.svg',
  ),
  GharadOption(
    title: 'توثيق إجراء رقابي أو تأديبي',
    description: 'لتوثيق مسطرة رقابية أو تأديبية في حدود الصلاحيات القانونية والتنظيمية',
    iconPath: 'assets/images/huissier/Folder File Warning.svg',
  ),
  GharadOption(
    title: 'توثيق لأغراض الشفافية والمساءلة',
    description: 'لتسجيل معطيات تُستعمل لإثبات حسن التدبير، احترام القانون الأساسي، أو الاستجابة لمتطلبات الشفافية',
    iconPath: 'assets/images/huissier/Balance.svg',
  ),
  GharadOption(
    title: 'معطيات أخرى أو حالات إضافية',
    description:
        'تُستعمل هذه الفقرة لإدراج أي معلومة، ظرف، أو ملاحظة ترى الهيئة أو الجمعية أنها مهمة، ولم تندرج ضمن الغايات أعلاه، دون أن تُعدّ هذه الإضافة قراراً أو إجراءً مستقلاً في حد ذاته',
    autoFields: '• طبيعة المعطى (اختياري):\n'
        'قرار تنظيمي – اجتماع – نشاط – مراسلة – شراكة – تدبير مالي – نظام داخلي – إجراء رقابي – ملاحظة مؤسسية – أخرى\n\n'
        '• مصدر المعلومة (اختياري):\n'
        'الهيئة – المكتب المسير – لجنة مختصة – عضو – شريك – وثيقة رسمية',
    iconPath: 'assets/images/huissier/Folder File Add Plus.svg',
  ),
];
