// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import 'text_input.dart';

export 'text_input.dart' show TextEditingValue, TextInputClient, TextInputConfiguration, TextInputConnection;

class AutofillHints {
  // This class is not meant to be instantiated or extended; this constructor
  // prevents instantiation and extension.
  AutofillHints._();

  static const String addressCity = 'addressCity';

  static const String addressCityAndState = 'addressCityAndState';

  static const String addressState = 'addressState';

  static const String birthday = 'birthday';

  static const String birthdayDay = 'birthdayDay';

  static const String birthdayMonth = 'birthdayMonth';

  static const String birthdayYear = 'birthdayYear';

  static const String countryCode = 'countryCode';

  static const String countryName = 'countryName';

  static const String creditCardExpirationDate = 'creditCardExpirationDate';

  static const String creditCardExpirationDay = 'creditCardExpirationDay';

  static const String creditCardExpirationMonth = 'creditCardExpirationMonth';

  static const String creditCardExpirationYear = 'creditCardExpirationYear';

  static const String creditCardFamilyName = 'creditCardFamilyName';

  static const String creditCardGivenName = 'creditCardGivenName';

  static const String creditCardMiddleName = 'creditCardMiddleName';

  static const String creditCardName = 'creditCardName';

  static const String creditCardNumber = 'creditCardNumber';

  static const String creditCardSecurityCode = 'creditCardSecurityCode';

  static const String creditCardType = 'creditCardType';

  static const String email = 'email';

  static const String familyName = 'familyName';

  static const String fullStreetAddress = 'fullStreetAddress';

  static const String gender = 'gender';

  static const String givenName = 'givenName';

  static const String impp = 'impp';

  static const String jobTitle = 'jobTitle';

  static const String language = 'language';

  static const String location = 'location';

  static const String middleInitial = 'middleInitial';

  static const String middleName = 'middleName';

  static const String name = 'name';

  static const String namePrefix = 'namePrefix';

  static const String nameSuffix = 'nameSuffix';

  static const String newPassword = 'newPassword';

  static const String newUsername = 'newUsername';

  static const String nickname = 'nickname';

  static const String oneTimeCode = 'oneTimeCode';

  static const String organizationName = 'organizationName';

  static const String password = 'password';

  static const String photo = 'photo';

  static const String postalAddress = 'postalAddress';

  static const String postalAddressExtended = 'postalAddressExtended';

  static const String postalAddressExtendedPostalCode = 'postalAddressExtendedPostalCode';

  static const String postalCode = 'postalCode';

  static const String streetAddressLevel1 = 'streetAddressLevel1';

  static const String streetAddressLevel2 = 'streetAddressLevel2';

  static const String streetAddressLevel3 = 'streetAddressLevel3';

  static const String streetAddressLevel4 = 'streetAddressLevel4';

  static const String streetAddressLine1 = 'streetAddressLine1';

  static const String streetAddressLine2 = 'streetAddressLine2';

  static const String streetAddressLine3 = 'streetAddressLine3';

  static const String sublocality = 'sublocality';

  static const String telephoneNumber = 'telephoneNumber';

  static const String telephoneNumberAreaCode = 'telephoneNumberAreaCode';

  static const String telephoneNumberCountryCode = 'telephoneNumberCountryCode';

  static const String telephoneNumberDevice = 'telephoneNumberDevice';

  static const String telephoneNumberExtension = 'telephoneNumberExtension';

  static const String telephoneNumberLocal = 'telephoneNumberLocal';

  static const String telephoneNumberLocalPrefix = 'telephoneNumberLocalPrefix';

  static const String telephoneNumberLocalSuffix = 'telephoneNumberLocalSuffix';

  static const String telephoneNumberNational = 'telephoneNumberNational';

  static const String transactionAmount = 'transactionAmount';

  static const String transactionCurrency = 'transactionCurrency';

  static const String url = 'url';

  static const String username = 'username';
}

@immutable
class AutofillConfiguration {
  const AutofillConfiguration({
    required String uniqueIdentifier,
    required List<String> autofillHints,
    required TextEditingValue currentEditingValue,
    String? hintText,
  }) : this._(
    enabled: true,
    uniqueIdentifier: uniqueIdentifier,
    autofillHints: autofillHints,
    currentEditingValue: currentEditingValue,
    hintText: hintText,
  );

  const AutofillConfiguration._({
    required this.enabled,
    required this.uniqueIdentifier,
    this.autofillHints = const <String>[],
    this.hintText,
    required this.currentEditingValue,
  });

  static const AutofillConfiguration disabled = AutofillConfiguration._(
    enabled: false,
    uniqueIdentifier: '',
    currentEditingValue: TextEditingValue.empty,
  );

  final bool enabled;

  final String uniqueIdentifier;

  final List<String> autofillHints;

  final TextEditingValue currentEditingValue;

  final String? hintText;

  Map<String, dynamic>? toJson() {
    return enabled
      ? <String, dynamic>{
          'uniqueIdentifier': uniqueIdentifier,
          'hints': autofillHints,
          'editingValue': currentEditingValue.toJSON(),
          if (hintText != null) 'hintText': hintText,
        }
      : null;
  }
}

abstract class AutofillClient {
  String get autofillId;

  TextInputConfiguration get textInputConfiguration;

  void autofill(TextEditingValue newEditingValue);
}

abstract class AutofillScope {
  AutofillClient? getAutofillClient(String autofillId);

  Iterable<AutofillClient> get autofillClients;

  TextInputConnection attach(TextInputClient trigger, TextInputConfiguration configuration);
}

@immutable
class _AutofillScopeTextInputConfiguration extends TextInputConfiguration {
  _AutofillScopeTextInputConfiguration({
    required this.allConfigurations,
    required TextInputConfiguration currentClientConfiguration,
  }) : super(inputType: currentClientConfiguration.inputType,
         obscureText: currentClientConfiguration.obscureText,
         autocorrect: currentClientConfiguration.autocorrect,
         smartDashesType: currentClientConfiguration.smartDashesType,
         smartQuotesType: currentClientConfiguration.smartQuotesType,
         enableSuggestions: currentClientConfiguration.enableSuggestions,
         inputAction: currentClientConfiguration.inputAction,
         textCapitalization: currentClientConfiguration.textCapitalization,
         keyboardAppearance: currentClientConfiguration.keyboardAppearance,
         actionLabel: currentClientConfiguration.actionLabel,
         autofillConfiguration: currentClientConfiguration.autofillConfiguration,
       );

  final Iterable<TextInputConfiguration> allConfigurations;

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = super.toJson();
    result['fields'] = allConfigurations
      .map((TextInputConfiguration configuration) => configuration.toJson())
      .toList(growable: false);
    return result;
  }
}

mixin AutofillScopeMixin implements AutofillScope {
  @override
  TextInputConnection attach(TextInputClient trigger, TextInputConfiguration configuration) {
    assert(
      !autofillClients.any((AutofillClient client) => !client.textInputConfiguration.autofillConfiguration.enabled),
      'Every client in AutofillScope.autofillClients must enable autofill',
    );

    final TextInputConfiguration inputConfiguration = _AutofillScopeTextInputConfiguration(
      allConfigurations: autofillClients.map((AutofillClient client) => client.textInputConfiguration),
      currentClientConfiguration: configuration,
    );
    return TextInput.attach(trigger, inputConfiguration);
  }
}