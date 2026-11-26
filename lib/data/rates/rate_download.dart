import 'dart:convert';
import 'dart:io';

import '../../utils/utils.dart';
import '../models/models.dart';

/// Gets [url] (or posts [body] to it) and returns the response's text;
/// throws a [RateDownloadException] if the server doesn't answer 200 (404:
/// null, the ECB's "no rates in that time").
typedef RateFetch = Future<String?> Function(
  Uri url, {
  String? body,
  Map<String, String> headers,
});

class RateDownloadException implements Exception {
  const RateDownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Downloads the exchange rates of the MNB (SOAP web service, HUF per
/// unit) and the ECB (data API, units per EUR). Only dates and currency
/// codes are sent.
class RateDownloader {
  RateDownloader({RateFetch? fetch}) : _fetch = fetch ?? _httpFetch;

  final RateFetch _fetch;

  /// The MNB's web service. Its WSDL gives this http address; https
  /// answers 404 to SOAP calls.
  static final Uri mnbUrl = Uri.parse('http://www.mnb.hu/arfolyamok.asmx');

  static const String _ecbApi =
      'https://data-api.ecb.europa.eu/service/data/EXR';

  /// The rates of [source] for [currencies] (the source's pivot left out)
  /// from [from] to [to].
  Future<List<ExchangeRate>> download(
    RateSource source,
    Set<Currency> currencies,
    DateTime from,
    DateTime to,
  ) async {
    final codes = [
      for (final c in currencies)
        if (c != source.pivot) c.code,
    ]..sort();
    if (codes.isEmpty || from.isAfter(to)) return const [];
    switch (source) {
      case RateSource.mnb:
        final text = await _fetch(
          mnbUrl,
          headers: const {
            'Content-Type': 'text/xml; charset=utf-8',
            'SOAPAction':
                '"http://www.mnb.hu/webservices/MNBArfolyamServiceSoap/'
                'GetExchangeRates"',
          },
          body: mnbRequest(codes, from, to),
        );
        return text == null ? const [] : parseMnb(text);
      case RateSource.ecb:
        final url = Uri.parse(
          '$_ecbApi/D.${codes.join('+')}.EUR.SP00.A'
          '?startPeriod=${Entry.dateText(from)}'
          '&endPeriod=${Entry.dateText(to)}&format=csvdata',
        );
        final text = await _fetch(url);
        return text == null ? const [] : parseEcb(text);
      case RateSource.manual:
        return const [];
    }
  }

  /// The SOAP call of the MNB's GetExchangeRates.
  static String mnbRequest(List<String> codes, DateTime from, DateTime to) =>
      '<?xml version="1.0" encoding="utf-8"?>'
      '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" '
      'xmlns:web="http://www.mnb.hu/webservices/"><soap:Body>'
      '<web:GetExchangeRates>'
      '<web:startDate>${Entry.dateText(from)}</web:startDate>'
      '<web:endDate>${Entry.dateText(to)}</web:endDate>'
      '<web:currencyNames>${codes.join(',')}</web:currencyNames>'
      '</web:GetExchangeRates></soap:Body></soap:Envelope>';

  /// The rates of the MNB's answer: its result is XML escaped in the SOAP
  /// envelope, `<Day date="2026-11-20"><Rate unit="100" curr="JPY">214,31`
  /// (HUF per [unit]). Currencies the app doesn't have are left out.
  static List<ExchangeRate> parseMnb(String response) {
    final xml = response
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&');
    final days = RegExp(
      r'<Day date="(\d{4}-\d{2}-\d{2})">(.*?)</Day>',
      dotAll: true,
    );
    final rates = RegExp(
      r'<Rate unit="(\d+)" curr="([A-Z]{3})">([\d.,]+)</Rate>',
    );
    return [
      for (final day in days.allMatches(xml))
        for (final rate in rates.allMatches(day[2]!))
          if (_currency(rate[2]!) case final currency?)
            if (_number(rate[3]!) case final value? when value > 0)
              ExchangeRate(
                source: RateSource.mnb,
                date: DateTime.parse(day[1]!),
                currency: currency,
                base: Currency.huf,
                rate: value / int.parse(rate[1]!),
              ),
    ];
  }

  /// The rates of the ECB's CSV answer (columns CURRENCY, CURRENCY_DENOM,
  /// TIME_PERIOD, OBS_VALUE: units of CURRENCY per EUR), stored as the value
  /// of a unit in EUR.
  static List<ExchangeRate> parseEcb(String csv) {
    final lines = const LineSplitter()
        .convert(csv)
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return const [];
    final header = _csvFields(lines.first);
    final currencyAt = header.indexOf('CURRENCY');
    final denomAt = header.indexOf('CURRENCY_DENOM');
    final dateAt = header.indexOf('TIME_PERIOD');
    final valueAt = header.indexOf('OBS_VALUE');
    if ([currencyAt, denomAt, dateAt, valueAt].contains(-1)) {
      throw const RateDownloadException('Unexpected ECB answer');
    }
    final result = <ExchangeRate>[];
    for (final line in lines.skip(1)) {
      final fields = _csvFields(line);
      if (fields.length <= valueAt || fields[denomAt] != 'EUR') continue;
      final currency = _currency(fields[currencyAt]);
      final value = double.tryParse(fields[valueAt]);
      final date = DateTime.tryParse(fields[dateAt]);
      if (currency == null || value == null || value <= 0 || date == null) {
        continue;
      }
      result.add(
        ExchangeRate(
          source: RateSource.ecb,
          date: date,
          currency: currency,
          base: Currency.eur,
          rate: 1 / value,
        ),
      );
    }
    return result;
  }

  static Currency? _currency(String code) =>
      Currency.values.where((c) => c.code == code).firstOrNull;

  static double? _number(String text) =>
      double.tryParse(text.replaceAll(',', '.'));

  /// The fields of a CSV line; quoted fields may have commas.
  static List<String> _csvFields(String line) {
    final fields = <String>[];
    final field = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (quoted) {
        if (char == '"' && i + 1 < line.length && line[i + 1] == '"') {
          field.write('"');
          i++;
        } else if (char == '"') {
          quoted = false;
        } else {
          field.write(char);
        }
      } else if (char == '"') {
        quoted = true;
      } else if (char == ',') {
        fields.add(field.toString());
        field.clear();
      } else {
        field.write(char);
      }
    }
    fields.add(field.toString());
    return fields;
  }
}

Future<String?> _httpFetch(
  Uri url, {
  String? body,
  Map<String, String> headers = const {},
}) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20)
    ..userAgent = 'Fineva';
  try {
    final request = body == null
        ? await client.getUrl(url)
        : await client.postUrl(url);
    headers.forEach(request.headers.set);
    if (body != null) request.add(utf8.encode(body));
    final response = await request.close().timeout(const Duration(seconds: 60));
    final text = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 60));
    if (response.statusCode == HttpStatus.notFound && body == null) {
      return null;
    }
    if (response.statusCode != HttpStatus.ok) {
      throw RateDownloadException('${url.host}: HTTP ${response.statusCode}');
    }
    return text;
  } on SocketException catch (e) {
    throw RateDownloadException('${url.host}: ${e.message}');
  } finally {
    client.close();
  }
}
