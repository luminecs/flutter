import 'package:flutter/widgets.dart';

import 'check_box_list_tile.dart';
import 'date_picker.dart';
import 'dialog.dart';
import 'slider.dart';
import 'text_field.dart';
import 'text_field_password.dart';

abstract class UseCase {
  String get name;
  String get route;
  Widget build(BuildContext context);
}

final List<UseCase> useCases = <UseCase>[
  CheckBoxListTile(),
  DialogUseCase(),
  SliderUseCase(),
  TextFieldUseCase(),
  TextFieldPasswordUseCase(),
  DatePickerUseCase(),
];