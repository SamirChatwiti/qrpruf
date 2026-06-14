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

const List<GharadOption> mohamiGharadOptions = [
  GharadOption(
    title: 'إثبات مباشرة إجراء قانوني',
    description:
        'لإثبات أن المحامي باشر إجراءً قانونيًا معيّنًا في وقت وتاريخ محددين، كإيداع مقال، تقديم مذكرة، أو القيام بخطوة مسطرية.',
    iconPath: 'assets/images/mohami/Courthouse.svg',
  ),
  GharadOption(
    title: 'إثبات الحضور في جلسة',
    description:
        'لتوثيق حضور جلسة، تأجيلها، غياب أحد الأطراف، أو سيرها العام، دون حلول محل المحضر القضائي.',
    iconPath: 'assets/images/mohami/User shield.svg',
  ),
  GharadOption(
    title: 'توثيق تبليغ أو تسليم وثائق',
    description:
        'لإثبات تسليم أو توصل بوثائق أو مستندات مرتبطة بملف قضائي أو استشارة قانونية.',
    iconPath: 'assets/images/mohami/Give Document.svg',
  ),
  GharadOption(
    title: 'توثيق امتناع أو تعذر',
    description:
        'لتوثيق امتناع أو تعذر أي إجراء أو تسليم وثيقة أو غيرها.',
    iconPath: 'assets/images/mohami/Shield error.svg',
  ),
  GharadOption(
    title: 'إثبات القيام بزيارة أو معاينة',
    description:
        'لإثبات القيام بزيارة ميدانية أو معاينة لواقعة معينة مرتبطة بالملف.',
    iconPath: 'assets/images/mohami/Video folder.svg',
  ),
  GharadOption(
    title: 'توثيق حالة استعجالية',
    description:
        'لتوثيق حالة استعجال، ضغط زمني، أو ظرف طارئ فرض اتخاذ قرار أو إجراء عاجl.',
    iconPath: 'assets/images/mohami/Clock exclamation.svg',
  ),
  GharadOption(
    title: 'إثبات وضعية ملف أو إجراء',
    description:
        'لتوثيق وضعية ملف معين أو إجراء إداري أو مهني.',
    iconPath: 'assets/images/mohami/Folder Cog.svg',
  ),
  GharadOption(
    title: 'إثبات نيابة أو تمثيل',
    description:
        'لإثبات النيابة عن الموكل أو تمثيله في جلسة أو لقاء أو غير ذلك.',
    iconPath: 'assets/images/mohami/User cog.svg',
  ),
  GharadOption(
    title: 'توثيق اجتماع أو مفاوضات',
    description:
        'لتوثيق سير اجتماع أو مفاوضات أو لقاء مهني.',
    iconPath: 'assets/images/mohami/Briefcase.svg',
  ),
  GharadOption(
    title: 'غاية أخرى',
    description:
        'تكتب هنا أي غاية أخرى لم يشملها التصنيف أعلاه.',
    iconPath: 'assets/images/mohami/Folder File Add Plus.svg',
  ),
];
