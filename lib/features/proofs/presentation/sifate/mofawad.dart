
class GharadField {
  const GharadField({
    required this.label,
    this.optional = false,
    this.multiline = false,
  });

  final String label;
  final bool optional;
  final bool multiline;
}

class GharadOption {
  const GharadOption({
    required this.title,
    required this.description,
    required this.fields,
    this.reportTemplate,
    this.iconPath,
  });

  final String title;
  final String description;
  final List<GharadField> fields;
  final String? reportTemplate;
  final String? iconPath;

  String get autoFields => fields.map((field) => '• ${field.label}').join(' • ');
}

const List<GharadOption> mofawadGharadOptions = [
  GharadOption(
    title: 'إثبات تواجد أو قيام بفعل',
    description: '',
    fields: [
      GharadField(label: 'مكان المعاينة'),
      GharadField(label: 'وصف الحالة كما تمت معاينتها', multiline: true),
      GharadField(label: 'وسائط داعمة (صور / فيديو)'),
    ],
    iconPath: 'assets/images/huissier/Document Scan.svg',
  ),
  GharadOption(
    title: 'توثيق امتناع أو عدم امتثال',
    description: '',
    fields: [
      GharadField(label: 'هوية الممتنع'),
      GharadField(label: 'الفعل المطلوب'),
      GharadField(label: 'صيغة الامتناع (صريح / ضمني)'),
    ],
    iconPath: 'assets/images/huissier/disallow.svg',
  ),
  GharadOption(
    title: 'توثيق تبليغ',
    description: '',
    fields: [
      GharadField(label: 'نوع الوثيقة'),
      GharadField(label: 'الجهة المبلَّغة'),
      GharadField(label: 'طريقة التبليغ'),
    ],
    iconPath: 'assets/images/huissier/email document.svg',
  ),
  GharadOption(
    title: 'توثيق تعذر التبليغ',
    description: '',
    fields: [
      GharadField(label: 'سبب التعذر'),
      GharadField(label: 'عدد المحاولات السابقة'),
      GharadField(label: 'توقيت كل محاولة سابقة'),
      GharadField(label: 'وضعية المكان'),
    ],
    iconPath: 'assets/images/huissier/Folder File Warning.svg',
  ),
  GharadOption(
    title: 'توثيق تسليم قانوني',
    description: '',
    fields: [
      GharadField(label: 'موضوع التسليم'),
      GharadField(label: 'المستلم'),
      GharadField(label: 'حالة التسليم'),
      GharadField(label: 'إثبات الاستلام'),
    ],
    iconPath: 'assets/images/huissier/Give Document.svg',
  ),
  GharadOption(
    title: 'توثيق رفض الاستلام',
    description: '',
    fields: [
      GharadField(label: 'هوية الرافض'),
      GharadField(label: 'موضوع الاستلام'),
      GharadField(label: 'صيغة الرفض'),
      GharadField(label: 'الشهود (إن وجدوا)', optional: true),
    ],
    iconPath: 'assets/images/huissier/User delete.svg',
  ),
  GharadOption(
    title: 'توثيق حالة غياب أو محل مغلق',
    description: '',
    fields: [
      GharadField(label: 'حالة المكان'),
      GharadField(label: 'محاولات الاتصال'),
      GharadField(label: 'ملاحظات إضافية', optional: true, multiline: true),
    ],
    iconPath: 'assets/images/huissier/User board.svg',
  ),
  GharadOption(
    title: 'توثيق تصريح أو جواب',
    description: '',
    fields: [
      GharadField(label: 'هوية المصرّح'),
      GharadField(label: 'صيغة التصريح (حرفي)', multiline: true),
      GharadField(label: 'سياق التصريح'),
      GharadField(label: 'توقيت التصريح'),
    ],
    iconPath: 'assets/images/huissier/Square message edit text.svg',
  ),
  GharadOption(
    title: 'توثيق تنفيذ إجراء قضائي',
    description: '',
    fields: [
      GharadField(label: 'نوع الإجراء'),
      GharadField(label: 'المرجع القضائي'),
      GharadField(label: 'طريقة التنفيذ'),
      GharadField(label: 'نتيجة التنفيذ'),
    ],
    iconPath: 'assets/images/huissier/Balance.svg',
  ),
  GharadOption(
    title: 'معطيات أخرى أو حالات إضافية',
    description:
        'تكتب هنا أي معلومة، حالة، أو ظرف إضافي ترى أنه مهم ولم يشمله التوثيق أعلاه.',
    fields: [
      GharadField(
        label:
            'طبيعة المعطى (اختياري):',
        optional: true,
        multiline: true,
      ),
      GharadField(
        label:
            'مصدر المعلومة (اختياري):',
        optional: true,
        multiline: true,
      ),
      GharadField(
        label:
            'إرفاق ملف داعم(اختياري):',
        optional: true,
      ),
    ],
    iconPath: 'assets/images/huissier/Folder File Add Plus.svg',
  ),
];
