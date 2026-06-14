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

const List<GharadOption> expertGharadOptions = [
  GharadOption(
    title: 'توثيق إنجاز بحث أو دراسة',
    description: 'لتوثيق إعداد بحث علمي، دراسة تحليلية، أو عمل خِبروي في تاريخ محدد ووفق المنهج المعتمد',
    iconPath: 'assets/images/huissier/User board.svg',
  ),
  GharadOption(
    title: 'توثيق فرضية أو إشكالية بحثية',
    description: 'لتسجيل فرضية، إشكالية، أو سؤال بحثي يشكّل منطلق العمل العلمي أو الخِبروي',
    iconPath: 'assets/images/huissier/Square message edit text.svg',
  ),
  GharadOption(
    title: 'توثيق جمع المعطيات أو المعاينات',
    description: 'لتوثيق عملية جمع المعطيات، إجراء مقابلات، معاينات ميدانية، أو تجارب علمية',
    iconPath: 'assets/images/huissier/Document Scan.svg',
  ),
  GharadOption(
    title: 'توثيق منهجية البحث أو الخبرة',
    description: 'لتسجيل المنهج المعتمد، الأدوات المستعملة، وخطوات التحليل أو التقييم',
    iconPath: 'assets/images/huissier/Square message edit text.svg',
  ),
  GharadOption(
    title: 'توثيق نتائج أو خلاصات مرحلية',
    description: 'لتوثيق نتائج أولية، مؤشرات، أو خلاصات مرحلية قبل الوصول إلى التقرير النهائي',
    iconPath: 'assets/images/chakhsi/Clock dash.svg',
  ),
  GharadOption(
    title: 'توثيق تحليل أو تقييم خِبروي',
    description: 'لتسجيل تحليل علمي أو تقييم خِبروي لموضوع أو واقعة ضمن نطاق الاختصاص',
    iconPath: 'assets/images/huissier/Document Scan.svg',
  ),
  GharadOption(
    title: 'توثيق مصدر معلومة أو مرجع علمي',
    description: 'لإثبات مصدر معلومة، مرجع علمي، وثيقة، أو قاعدة بيانات معتمدة في البحث أو الخبرة',
    iconPath: 'assets/images/huissier/Give Document.svg',
  ),
  GharadOption(
    title: 'توثيق مراجعة علمية أو تحكيم',
    description: 'لتوثيق مراجعة علمية، تحكيم، أو تقييم خارجي لبحث أو تقرير خِبروي',
    iconPath: 'assets/images/chakhsi/User checked.svg',
  ),
  GharadOption(
    title: 'توثيق لأغراض النزاهة والمسؤولية العلمية',
    description: 'لتسجيل عناصر تُستعمل لإثبات النزاهة العلمية، احترام أخلاقيات البحث، واستقلالية الرأي الخِبروي',
    iconPath: 'assets/images/huissier/Balance.svg',
  ),
  GharadOption(
    title: 'معطيات أخرى أو حالات إضافية',
    description:
        'تُستعمل هذه الفقرة لإدراج أي معلومة، ظرف، أو ملاحظة علمية يرى الباحث أو الخبير أنها مهمة، ولم تندرج ضمن الغايات أعلاه، دون أن تُعدّ هذه الإضافة بحثاً أو تقريراً خِبروياً مستقلاً في حد ذاته',
    autoFields: '• طبيعة المعطى (اختياري):\n'
        'بحث علمي – فرضية – معطيات – منهجية – نتائج مرحلية – تحليل خِبروي – مرجع علمي – مراجعة – ملاحظة علمية – أخرى\n\n'
        '• مصدر المعلومة (اختياري):\n'
        'الباحث – الخبير – مقابلة – تجربة – قاعدة بيانات – وثيقة علمية – مرجع منشور',
    iconPath: 'assets/images/huissier/Folder File Add Plus.svg',
  ),
];
