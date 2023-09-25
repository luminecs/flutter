
import 'base/io.dart';
import 'base/platform.dart';
import 'doctor_validator.dart';

class ProxyValidator extends DoctorValidator {
  ProxyValidator({
    required Platform platform,
  })  : shouldShow = _getEnv('HTTP_PROXY', platform).isNotEmpty,
        _httpProxy = _getEnv('HTTP_PROXY', platform),
        _noProxy = _getEnv('NO_PROXY', platform),
        super('Proxy Configuration');

  final bool shouldShow;
  final String _httpProxy;
  final String _noProxy;

  static String _getEnv(String key, Platform platform) =>
    platform.environment[key.toLowerCase()]?.trim() ??
    platform.environment[key.toUpperCase()]?.trim() ??
    '';

  @override
  Future<ValidationResult> validate() async {
    if (_httpProxy.isEmpty) {
      return const ValidationResult(
          ValidationType.success, <ValidationMessage>[]);
    }

    final List<ValidationMessage> messages = <ValidationMessage>[
      const ValidationMessage('HTTP_PROXY is set'),
      if (_noProxy.isEmpty)
        const ValidationMessage.hint('NO_PROXY is not set')
      else
        ...<ValidationMessage>[
          ValidationMessage('NO_PROXY is $_noProxy'),
          for (final String host in await _getLoopbackAddresses())
            if (_noProxy.contains(host))
              ValidationMessage('NO_PROXY contains $host')
            else
              ValidationMessage.hint('NO_PROXY does not contain $host'),
        ],
    ];

    final bool hasIssues = messages.any(
      (ValidationMessage msg) => msg.isHint || msg.isError);

    return ValidationResult(
      hasIssues ? ValidationType.partial : ValidationType.success,
      messages,
    );
  }

  Future<List<String>> _getLoopbackAddresses() async {
    final List<String> loopBackAddresses = <String>['localhost'];

    final List<NetworkInterface> networkInterfaces =
      await listNetworkInterfaces(includeLinkLocal: true, includeLoopback: true);

    for (final NetworkInterface networkInterface in networkInterfaces) {
      for (final InternetAddress internetAddress in networkInterface.addresses) {
        if (internetAddress.isLoopback) {
          loopBackAddresses.add(internetAddress.address);
        }
      }
    }

    return loopBackAddresses;
  }
}