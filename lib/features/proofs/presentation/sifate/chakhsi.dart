import 'package:flutter/widgets.dart';

class GharadOption {
  const GharadOption({
    required this.title,
    required this.description,
    this.iconPath,
  });

  final String title;
  final String description;
  final String? iconPath;

  String? get autoFields => null;
  String? get reportTemplate => null;
}

const TextDirection gharadTextDirection = TextDirection.rtl;

const List<GharadOption> chakhsiGharadOptions = [
  GharadOption(
    title: 'إثبات تواجد أو قيام بفعل',
    description: 'لإثبات أن شخصًا ما كان موجودًا أو قام بشيء في وقت ومكان محددين',
    iconPath: 'assets/images/chakhsi/User checked.svg',
  ),
  GharadOption(
    title: 'توثيق موعد أو حضور أو انتظار',
    description: 'لتوثيق الحضور، التأخر، الانتظار، أو الالتزام بموعد',
    iconPath: 'assets/images/chakhsi/Clock dash.svg',
  ),
  GharadOption(
    title: 'توثيق واقعة أو حدث معيّن',
    description: 'لتسجيل ما وقع كما هو، خاصة في الحالات غير المتوقعة أو الطارئة',
    iconPath: 'assets/images/chakhsi/Speaker megaphone.svg',
  ),
  GharadOption(
    title: 'توثيق تسليم أو استلام',
    description: 'لإثبات تسليم أو استلام شيء مادي أو رقمي',
    iconPath: 'assets/images/chakhsi/Delivery hand send.svg',
  ),
  GharadOption(
    title: 'توثيق ضرر أو خسارة',
    description: 'لتسجيل ضرر، عطب، خسارة، أو حالة غير سليمة',
    iconPath: 'assets/images/chakhsi/Error Triangle.svg',
  ),
  GharadOption(
    title: 'توثيق إجراء أو خطوة تنظيمية',
    description: 'لتسجيل إجراء، مسار عمل، أو خطوة تنظيمية تم تنفيذها',
    iconPath: 'assets/images/chakhsi/Layers.svg',
  ),
  GharadOption(
    title: 'توثيق معلومة للرجوع إليها لاحقًا',
    description: 'للاحتفاظ بمعلومة أو ملاحظة قصد الرجوع إليها عند الحاجة',
    iconPath: 'assets/images/chakhsi/Bookmark.svg',
  ),
  GharadOption(
    title: 'توثيق لأغراض الشفافية أو الإخبار',
    description: 'لتوضيح وضعية أو مشاركة معلومة مع الغير',
    iconPath: 'assets/images/chakhsi/Info Square.svg',
  ),
  GharadOption(
    title: 'توثيق للاستعمال الشخصي',
    description: 'لتوثيق خاص غير موجّه للغير أو للاستعمال الرسمي',
    iconPath: 'assets/images/chakhsi/User lock.svg',
  ),
  GharadOption(
    title: 'معطيات أخرى أو حالات إضافية',
    description:
        'تُستعمل هذه الفقرة لإضافة أي معلومة، حالة، أو ظرف يرى صاحب التوثيق أنه مهم، ولم يشمله التوثيق أعلاه، دون أن تُعدّ هذه الإضافة توثيقًا مستقلًا أو إثباتًا في حد ذاتها.',
    iconPath: 'assets/images/chakhsi/Delivery Boxes.svg',
  ),
];
