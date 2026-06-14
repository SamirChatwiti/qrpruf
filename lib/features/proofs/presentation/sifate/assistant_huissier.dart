import 'mofawad.dart';

const List<GharadOption> assistantGharadOptions = [
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
