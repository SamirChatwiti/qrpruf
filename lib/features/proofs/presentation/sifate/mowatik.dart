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

const List<GharadOption> mowatikGharadOptions = [
  GharadOption(
    title: 'توثيق إبرام عقد أو محرر رسمي',
    description:
        'لتوثيق إبرام عقد، محرر رسمي، أو تصرف قانوني خاضع للتوثيق، في تاريخ ومكان محددين ووفق الشكل القانوني.',
    iconPath: 'assets/images/huissier/Document Scan.svg',
  ),
  GharadOption(
    title: 'توثيق هوية الأطراف وأهليتهم',
    description:
        'للتحقق من هوية الأطراف وصفاتهم وأهليتهم القانونية للتعاقد، وإثبات ذلك ضمن محرر التوثيق.',
    iconPath: 'assets/images/mohami/User shield.svg',
  ),
  GharadOption(
    title: 'توثيق رضا الأطراف والتعبير عن الإرادة',
    description:
        'لإثبات رضا الأطراف الحرّ والصريح بمضمون التصرف القانوني، وانتفاء الإكراه أو الغلط الظاهر.',
    iconPath: 'assets/images/huissier/User board.svg',
  ),
  GharadOption(
    title: 'توثيق تسليم أو توصل بمستندات داعمة',
    description:
        'لتسجيل تسليم أو توصل الموثق بالوثائق والمستندات المعتمدة في إعداد العقد أو المحرر.',
    iconPath: 'assets/images/huissier/email document.svg',
  ),
  GharadOption(
    title: 'توثيق إيداع أو تسليم مبالغ أو ضمانات',
    description:
        'لتوثيق إيداع، تسليم، أو تحويل مبالغ مالية أو ضمانات مرتبطة بالتصرف القانوني.',
    iconPath: 'assets/images/mohami/Briefcase.svg',
  ),
  GharadOption(
    title: 'توثيق مراحل إعداد العقد',
    description:
        'لتسجيل مراحل إعداد المحرر، الملاحظات، التعديلات، أو الصيغ الأولية قبل التوقيع النهائي.',
    iconPath: 'assets/images/mohami/Folder Cog.svg',
  ),
  GharadOption(
    title: 'توثيق توقيع الأطراف والإشهاد عليه',
    description:
        'لإثبات توقيع الأطراف على المحرر الرسمي، والإشهاد على صحته ومطابقته للإرادة المعبَّر عنها.',
    iconPath: 'assets/images/mohami/User cog.svg',
  ),
  GharadOption(
    title: 'توثيق إجراء تنظيمي أو مهني',
    description:
        'لتوثيق إجراء إداري أو مهني مرتبط بسير مكتب التوثيق أو بالعلاقة مع الإدارات والهيئات المختصة.',
    iconPath: 'assets/images/huissier/User board.svg',
  ),
  GharadOption(
    title: 'توثيق لأغراض التحوّط والمسؤولية المهنية',
    description:
        'لتسجيل عناصر تهدف إلى حماية الموثق من المنازعات، وإثبات احترامه لواجبات التحري، الإعلام، والنصح.',
    iconPath: 'assets/images/mohami/Shield error.svg',
  ),
  GharadOption(
    title: 'معطيات إضافية أو ملاحظات توثيقية عامة',
    description:
        'تُستعمل هذه الفقرة لإدراج أي معلومة، ظرف، أو ملاحظة يرى الموثق أنها ذات أهمية ولم تندرج ضمن الغايات أعلاه، دون أن تُعدّ توثيقًا مستقلاً أو إثباتًا قانونيًا في حد ذاته.',
    autoFields:
        '• طبيعة المعطى (اختياري):\n'
        'تصرف قانوني – تحقق من الهوية – رضا الأطراف – مستند داعم – إجراء مهني – ملاحظة توثيقية – أخرى\n\n'
        '• مصدر المعلومة (اختياري):\n'
        'أطراف العقد – الموثق – وثيقة رسمية – إدارة عمومية – تصريح مباشر – ملاحظة مهنية\n\n'
        '• إرفاق ملف داعم (اختياري):\n'
        'مستندات، نسخ، أو مراسلات تُرفق لأغراض الإعداد أو التوضيح، ولا تُعد تلقائيًا وسائل إثبات مستقلة إلا إذا أُشير إليها صراحة ضمن المحرر',
    iconPath: 'assets/images/huissier/Folder File Add Plus.svg',
  ),
];
