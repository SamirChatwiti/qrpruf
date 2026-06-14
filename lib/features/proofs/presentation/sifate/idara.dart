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

const List<GharadOption> idaraGharadOptions = [
  GharadOption(
    title: 'توثيق اتخاذ قرار إداري',
    description:
        'لتوثيق صدور قرار إداري في تاريخ معيّن، مع بيان سياقه والجهة المختصة به',
    iconPath: 'assets/images/huissier/User board.svg',
  ),
  GharadOption(
    title: 'توثيق إجراء إداري أو مسطري',
    description:
        'لتسجيل إجراء إداري تم إنجازه، أو مرحلة من مسطرة إدارية، وفق القوانين والأنظمة الجاري بها العمل',
    iconPath: 'assets/images/huissier/Square message edit text.svg',
  ),
  GharadOption(
    title: 'توثيق تبليغ أو إشعار إداري',
    description:
        'لإثبات تبليغ قرار، إشعار، أو مراسلة إدارية إلى المعنيين بالأمر',
    iconPath: 'assets/images/huissier/email document.svg',
  ),
  GharadOption(
    title: 'توثيق استقبال طلب أو ملف',
    description:
        'لتوثيق استلام طلب، شكاية، أو ملف إداري، مع تحديد تاريخ وساعة الإيداع',
    iconPath: 'assets/images/huissier/Give Document.svg',
  ),
  GharadOption(
    title: 'توثيق اجتماع أو مداولة إدارية',
    description:
        'لتسجيل انعقاد اجتماع، لجنة، أو مداولة إدارية، مع ضبط الحضور والنتائج العامة',
    iconPath: 'assets/images/huissier/User board.svg',
  ),
  GharadOption(
    title: 'توثيق خدمة مقدمة للمرتفق',
    description:
        'لتوثيق تقديم خدمة إدارية للمرتفق، أو إنجاز معاملة إدارية لفائدته',
    iconPath: 'assets/images/chakhsi/User checked.svg',
  ),
  GharadOption(
    title: 'توثيق واقعة أو ظرف إداري استثنائي',
    description:
        'لتسجيل واقعة غير عادية، خلل، أو ظرف استثنائي أثّر على سير المرفق العمومي',
    iconPath: 'assets/images/chakhsi/Info Square.svg',
  ),
  GharadOption(
    title: 'توثيق إجراء رقابي أو تفتيشي',
    description:
        'لتوثيق عملية مراقبة، تفتيش، أو افتحاص إداري، في حدود الاختصاص القانوني',
    iconPath: 'assets/images/huissier/Balance.svg',
  ),
  GharadOption(
    title: 'توثيق لأغراض الشفافية والمساءلة الإدارية',
    description:
        'لتسجيل معطيات تُستعمل لإثبات حسن التدبير، احترام المساطر، أو الاستجابة لمتطلبات الشفافية',
    iconPath: 'assets/images/huissier/disallow.svg',
  ),
  GharadOption(
    title: 'معطيات أخرى أو حالات إضافية',
    description:
        'تُستعمل هذه الفقرة لإدراج أي معلومة، ظرف، أو ملاحظة إدارية يرى المسؤول أو الموظف أنها مهمة، ولم تندرج ضمن الغايات أعلاه، دون أن تُعدّ هذه الإضافة قراراً أو إجراءً مستقلاً في حد ذاته',
    autoFields: '• طبيعة المعطى (اختياري):\n'
        'قرار إداري – إجراء مسطري – تبليغ – طلب – اجتماع – خدمة عمومية – واقعة استثنائية – مراقبة – ملاحظة إدارية – أخرى\n\n'
        '• مصدر المعلومة (اختياري):\n'
        'الإدارة المعنية – الموظف المختص – المرتفق – وثيقة رسمية – نظام معلوماتي – محضر إداري',
    iconPath: 'assets/images/huissier/Folder File Add Plus.svg',
  ),
];
