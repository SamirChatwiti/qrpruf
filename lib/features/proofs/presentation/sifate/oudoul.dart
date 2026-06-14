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

const List<GharadOption> oudoulGharadOptions = [
  GharadOption(
    title: 'توثيق الإشهاد على تصرّف شرعي أو قانوني',
    description:
        'لتوثيق الإشهاد على تصرّف شرعي أو قانوني وفق الصيغة العدلية المعتمدة، وفي زمان ومكان محددين.',
    iconPath: 'assets/images/huissier/Document Scan.svg',
  ),
  GharadOption(
    title: 'توثيق هوية المشهود عليهم وصفاتهم',
    description:
        'للتحقق من هوية المشهود عليهم، صفاتهم، وأهليتهم الشرعية والقانونية، وإثبات ذلك ضمن وثيقة الإشهاد.',
    iconPath: 'assets/images/mohami/User shield.svg',
  ),
  GharadOption(
    title: 'توثيق رضا الأطراف وانتفاء الإكراه',
    description:
        'لإثبات رضا الأطراف الصريح، وانتفاء الإكراه أو الغرر الظاهر، وفق مقتضيات الإشهاد العدلي.',
    iconPath: 'assets/images/huissier/User board.svg',
  ),
  GharadOption(
    title: 'توثيق حضور الأطراف والشهود',
    description:
        'لتسجيل حضور الأطراف والشهود، وضبط ظروف وسياق الإشهاد بدقة.',
    iconPath: 'assets/images/huissier/User board.svg',
  ),
  GharadOption(
    title: 'توثيق تسليم أو توصل بوثائق داعمة',
    description:
        'لتوثيق تسليم أو توصل العدول بالوثائق والمستندات المعتمدة في تحرير الرسم العدلي.',
    iconPath: 'assets/images/huissier/email document.svg',
  ),
  GharadOption(
    title: 'توثيق مراحل تحرير الرسم العدلي',
    description:
        'لتسجيل مراحل إعداد الرسم العدلي، والملاحظات أو التعديلات قبل تحريره في صيغته النهائية.',
    iconPath: 'assets/images/mohami/Folder Cog.svg',
  ),
  GharadOption(
    title: 'توثيق توقيع أو إمضاء المشهود عليهم',
    description:
        'لإثبات توقيع أو علامة المشهود عليهم، أو الإشهاد عليهم في حالة عدم التوقيع، طبقاً للضوابط العدلية.',
    iconPath: 'assets/images/mohami/User cog.svg',
  ),
  GharadOption(
    title: 'توثيق إجراء عدلي أو تنظيمي مهني',
    description:
        'لتوثيق إجراء مهني أو تنظيمي مرتبط بسير مكتب العدول أو بالعلاقة مع الجهات المختصة.',
    iconPath: 'assets/images/huissier/User board.svg',
  ),
  GharadOption(
    title: 'توثيق لأغراض التحوّط والمسؤولية العدلية',
    description:
        'لتسجيل عناصر تُستعمل لاحقاً لإثبات احترام الضوابط العدلية، وحسن القيام بواجبات الإشهاد.',
    iconPath: 'assets/images/mohami/Shield error.svg',
  ),
  GharadOption(
    title: 'معطيات إضافية أو ملاحظات عدلية عامة',
    description:
        'تُستعمل هذه الفقرة لإدراج أي معلومة، ظرف، أو ملاحظة يرى العدل أنها ذات أهمية، ولم تندرج ضمن الغايات أعلاه، دون أن تُعدّ هذه الإضافة توثيقاً مستقلاً أو إثباتاً عدلياً في حد ذاته.',
    autoFields:
        '• طبيعة المعطى (اختياري):\n'
        'صرف شرعي – إشهاد عدلي – تحقق من الهوية – رضا الأطراف – حضور الشهود – مستند داعم – إجراء مهني – ملاحظة عدلية – أخرى\n\n'
        '• مصدر المعلومة (اختياري):\n'
        'المشهود عليهم – الشهود – العدل – وثيقة رسمية – تصريح مباشر – ملاحظة عدلية\n\n'
        '• إرفاق ملف داعم (اختياري):\n'
        'وثائق أو مستندات تُرفق لأغراض الإعداد أو التوضيح، ولا تُعد تلقائياً وسائل إثبات مستقلة إلا إذا أُشير إليها صراحة ضمن الرسم العدلي',
    iconPath: 'assets/images/huissier/Folder File Add Plus.svg',
  ),
];
