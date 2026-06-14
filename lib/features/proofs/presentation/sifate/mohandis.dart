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

const List<GharadOption> mohandisGharadOptions = [
  GharadOption(
    title: 'توثيق إنجاز دراسة أو تصميم هندسي',
    description:
        'لتوثيق إعداد دراسة تقنية، تصميم هندسي، أو مخطط، في تاريخ محدد ووفق المعايير المعتمدة',
    iconPath: 'assets/images/huissier/User board.svg',
  ),
  GharadOption(
    title: 'توثيق معاينة ميدانية أو زيارة تقنية',
    description:
        'لتسجيل معاينة ميدانية، زيارة ورش، أو تفقد منشأة، مع ضبط الملاحظات التقنية والحالة الواقعية',
    iconPath: 'assets/images/huissier/Document Scan.svg',
  ),
  GharadOption(
    title: 'توثيق مطابقة الأشغال للمواصفات',
    description:
        'للتحقق من مطابقة الأشغال أو المنشآت للدفاتر التقنية، المعايير، أو التصاميم المصادق عليها',
    iconPath: 'assets/images/huissier/Balance.svg',
  ),
  GharadOption(
    title: 'توثيق تقدم الأشغال أو مراحل الإنجاز',
    description:
        'لتسجيل مراحل تقدم المشروع، نسب الإنجاز، أو الأشغال المنجزة في فترة زمنية معينة',
    iconPath: 'assets/images/chakhsi/Clock dash.svg',
  ),
  GharadOption(
    title: 'توثيق اختبارات أو قياسات تقنية',
    description:
        'لتوثيق نتائج اختبارات، قياسات، أو تجارب تقنية أجريت على مواد أو تجهيزات أو منشآت',
    iconPath: 'assets/images/huissier/Document Scan.svg',
  ),
  GharadOption(
    title: 'توثيق عيب تقني أو خلل هندسي',
    description:
        'لتسجيل عيب، خلل، أو عدم مطابقة تقنية، مع بيان ظروف ظهوره وتأثيره المحتمل',
    iconPath: 'assets/images/huissier/Folder File Warning.svg',
  ),
  GharadOption(
    title: 'توثيق توجيهات تقنية أو توصيات هندسية',
    description:
        'لتوثيق توجيهات، حلول تقنية، أو توصيات هندسية موجهة لجهة معينة في إطار المشروع',
    iconPath: 'assets/images/huissier/Square message edit text.svg',
  ),
  GharadOption(
    title: 'توثيق إجراء تنظيمي أو مهني',
    description:
        'لتسجيل إجراء إداري أو مهني مرتبط بتسيير المشروع، المكتب الهندسي، أو العلاقة مع المتدخلين',
    iconPath: 'assets/images/huissier/disallow.svg',
  ),
  GharadOption(
    title: 'توثيق لأغراض التحوّط والمسؤولية المهنية',
    description:
        'لتوثيق عناصر تهدف إلى إثبات احترام المعايير التقنية، وحسن أداء المهام، والوقاية من النزاعات',
    iconPath: 'assets/images/huissier/Balance.svg',
  ),
  GharadOption(
    title: 'معطيات أخرى أو حالات إضافية',
    description:
        'تُستعمل هذه الفقرة لإدراج أي معلومة، ظرف، أو ملاحظة تقنية يرى المهندس أنها مهمة ولم تندرج ضمن الغايات أعلاه، دون أن تُعدّ توثيقاً مستقلاً أو تقريراً تقنياً كاملاً',
    autoFields: '• طبيعة المعطى (اختياري):\n'
        'دراسة تقنية – معاينة ميدانية – مطابقة – اختبار – قياس – خلل تقني – توصية هندسية – إجراء مهني – ملاحظة تقنية – أخرى\n\n'
        '• مصدر المعلومة (اختياري):\n'
        'المهندس – فريق المشروع – مقاول – مختبر – وثيقة تقنية – معاينة ميدانية',
    iconPath: 'assets/images/huissier/Folder File Add Plus.svg',
  ),
];
