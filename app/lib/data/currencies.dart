/// Current ISO 4217 currencies with their minor units, bundled so the app
/// works offline. Funds and precious metals are left out.
class Currency {
  const Currency(this.code, this.name, this.symbol, this.minorUnits);

  final String code;
  final String name;
  final String symbol;
  final int minorUnits;

  /// Whether the exchange-rate service publishes this currency.
  bool get hasAutoRate => autoRateCodes.contains(code);
}

/// Currencies the European Central Bank reference rates cover (Frankfurter).
const Set<String> autoRateCodes = {
  'AUD', 'BRL', 'CAD', 'CHF', 'CNY', 'CZK', 'DKK', 'EUR', 'GBP', 'HKD', //
  'HUF', 'IDR', 'ILS', 'INR', 'ISK', 'JPY', 'KRW', 'MXN', 'MYR',
  'NOK', 'NZD', 'PHP', 'PLN', 'RON', 'SEK', 'SGD', 'THB', 'TRY', 'USD',
  'ZAR',
};

const List<Currency> currencies = [
  Currency('AED', 'UAE Dirham', 'AED', 2),
  Currency('AFN', 'Afghan Afghani', '؋', 2),
  Currency('ALL', 'Albanian Lek', 'L', 2),
  Currency('AMD', 'Armenian Dram', '֏', 2),
  Currency('ANG', 'Netherlands Antillean Guilder', 'ƒ', 2),
  Currency('AOA', 'Angolan Kwanza', 'Kz', 2),
  Currency('ARS', 'Argentine Peso', r'$', 2),
  Currency('AUD', 'Australian Dollar', r'A$', 2),
  Currency('AWG', 'Aruban Florin', 'ƒ', 2),
  Currency('AZN', 'Azerbaijani Manat', '₼', 2),
  Currency('BAM', 'Bosnia-Herzegovina Convertible Mark', 'KM', 2),
  Currency('BBD', 'Barbadian Dollar', r'$', 2),
  Currency('BDT', 'Bangladeshi Taka', '৳', 2),
  Currency('BGN', 'Bulgarian Lev', 'лв', 2),
  Currency('BHD', 'Bahraini Dinar', 'BD', 3),
  Currency('BIF', 'Burundian Franc', 'FBu', 0),
  Currency('BMD', 'Bermudan Dollar', r'$', 2),
  Currency('BND', 'Brunei Dollar', r'$', 2),
  Currency('BOB', 'Bolivian Boliviano', 'Bs', 2),
  Currency('BRL', 'Brazilian Real', r'R$', 2),
  Currency('BSD', 'Bahamian Dollar', r'$', 2),
  Currency('BTN', 'Bhutanese Ngultrum', 'Nu.', 2),
  Currency('BWP', 'Botswanan Pula', 'P', 2),
  Currency('BYN', 'Belarusian Ruble', 'Br', 2),
  Currency('BZD', 'Belize Dollar', r'$', 2),
  Currency('CAD', 'Canadian Dollar', r'CA$', 2),
  Currency('CDF', 'Congolese Franc', 'FC', 2),
  Currency('CHF', 'Swiss Franc', 'CHF', 2),
  Currency('CLP', 'Chilean Peso', r'$', 0),
  Currency('CNY', 'Chinese Yuan', 'CN¥', 2),
  Currency('COP', 'Colombian Peso', r'$', 2),
  Currency('CRC', 'Costa Rican Colón', '₡', 2),
  Currency('CUP', 'Cuban Peso', r'$', 2),
  Currency('CVE', 'Cape Verdean Escudo', 'Esc', 2),
  Currency('CZK', 'Czech Koruna', 'Kč', 2),
  Currency('DJF', 'Djiboutian Franc', 'Fdj', 0),
  Currency('DKK', 'Danish Krone', 'kr', 2),
  Currency('DOP', 'Dominican Peso', r'RD$', 2),
  Currency('DZD', 'Algerian Dinar', 'DA', 2),
  Currency('EGP', 'Egyptian Pound', 'E£', 2),
  Currency('ERN', 'Eritrean Nakfa', 'Nfk', 2),
  Currency('ETB', 'Ethiopian Birr', 'Br', 2),
  Currency('EUR', 'Euro', '€', 2),
  Currency('FJD', 'Fijian Dollar', r'FJ$', 2),
  Currency('FKP', 'Falkland Islands Pound', '£', 2),
  Currency('GBP', 'British Pound', '£', 2),
  Currency('GEL', 'Georgian Lari', '₾', 2),
  Currency('GHS', 'Ghanaian Cedi', 'GH₵', 2),
  Currency('GIP', 'Gibraltar Pound', '£', 2),
  Currency('GMD', 'Gambian Dalasi', 'D', 2),
  Currency('GNF', 'Guinean Franc', 'FG', 0),
  Currency('GTQ', 'Guatemalan Quetzal', 'Q', 2),
  Currency('GYD', 'Guyanaese Dollar', r'$', 2),
  Currency('HKD', 'Hong Kong Dollar', r'HK$', 2),
  Currency('HNL', 'Honduran Lempira', 'L', 2),
  Currency('HTG', 'Haitian Gourde', 'G', 2),
  Currency('HUF', 'Hungarian Forint', 'Ft', 2),
  Currency('IDR', 'Indonesian Rupiah', 'Rp', 2),
  Currency('ILS', 'Israeli New Shekel', '₪', 2),
  Currency('INR', 'Indian Rupee', '₹', 2),
  Currency('IQD', 'Iraqi Dinar', 'IQD', 3),
  Currency('IRR', 'Iranian Rial', 'IRR', 2),
  Currency('ISK', 'Icelandic Króna', 'kr', 0),
  Currency('JMD', 'Jamaican Dollar', r'J$', 2),
  Currency('JOD', 'Jordanian Dinar', 'JD', 3),
  Currency('JPY', 'Japanese Yen', '¥', 0),
  Currency('KES', 'Kenyan Shilling', 'KSh', 2),
  Currency('KGS', 'Kyrgystani Som', 'som', 2),
  Currency('KHR', 'Cambodian Riel', '៛', 2),
  Currency('KMF', 'Comorian Franc', 'CF', 0),
  Currency('KPW', 'North Korean Won', '₩', 2),
  Currency('KRW', 'South Korean Won', '₩', 0),
  Currency('KWD', 'Kuwaiti Dinar', 'KD', 3),
  Currency('KYD', 'Cayman Islands Dollar', r'$', 2),
  Currency('KZT', 'Kazakhstani Tenge', '₸', 2),
  Currency('LAK', 'Laotian Kip', '₭', 2),
  Currency('LBP', 'Lebanese Pound', 'L£', 2),
  Currency('LKR', 'Sri Lankan Rupee', 'Rs', 2),
  Currency('LRD', 'Liberian Dollar', r'$', 2),
  Currency('LSL', 'Lesotho Loti', 'L', 2),
  Currency('LYD', 'Libyan Dinar', 'LD', 3),
  Currency('MAD', 'Moroccan Dirham', 'MAD', 2),
  Currency('MDL', 'Moldovan Leu', 'L', 2),
  Currency('MGA', 'Malagasy Ariary', 'Ar', 2),
  Currency('MKD', 'Macedonian Denar', 'den', 2),
  Currency('MMK', 'Myanmar Kyat', 'K', 2),
  Currency('MNT', 'Mongolian Tugrik', '₮', 2),
  Currency('MOP', 'Macanese Pataca', 'MOP', 2),
  Currency('MRU', 'Mauritanian Ouguiya', 'UM', 2),
  Currency('MUR', 'Mauritian Rupee', 'Rs', 2),
  Currency('MVR', 'Maldivian Rufiyaa', 'Rf', 2),
  Currency('MWK', 'Malawian Kwacha', 'MK', 2),
  Currency('MXN', 'Mexican Peso', r'MX$', 2),
  Currency('MYR', 'Malaysian Ringgit', 'RM', 2),
  Currency('MZN', 'Mozambican Metical', 'MT', 2),
  Currency('NAD', 'Namibian Dollar', r'$', 2),
  Currency('NGN', 'Nigerian Naira', '₦', 2),
  Currency('NIO', 'Nicaraguan Córdoba', r'C$', 2),
  Currency('NOK', 'Norwegian Krone', 'kr', 2),
  Currency('NPR', 'Nepalese Rupee', 'Rs', 2),
  Currency('NZD', 'New Zealand Dollar', r'NZ$', 2),
  Currency('OMR', 'Omani Rial', 'OMR', 3),
  Currency('PAB', 'Panamanian Balboa', 'B/.', 2),
  Currency('PEN', 'Peruvian Sol', 'S/', 2),
  Currency('PGK', 'Papua New Guinean Kina', 'K', 2),
  Currency('PHP', 'Philippine Peso', '₱', 2),
  Currency('PKR', 'Pakistani Rupee', 'Rs', 2),
  Currency('PLN', 'Polish Zloty', 'zł', 2),
  Currency('PYG', 'Paraguayan Guarani', '₲', 0),
  Currency('QAR', 'Qatari Riyal', 'QR', 2),
  Currency('RON', 'Romanian Leu', 'lei', 2),
  Currency('RSD', 'Serbian Dinar', 'din', 2),
  Currency('RUB', 'Russian Ruble', '₽', 2),
  Currency('RWF', 'Rwandan Franc', 'RF', 0),
  Currency('SAR', 'Saudi Riyal', 'SR', 2),
  Currency('SBD', 'Solomon Islands Dollar', r'$', 2),
  Currency('SCR', 'Seychellois Rupee', 'SR', 2),
  Currency('SDG', 'Sudanese Pound', 'SDG', 2),
  Currency('SEK', 'Swedish Krona', 'kr', 2),
  Currency('SGD', 'Singapore Dollar', r'S$', 2),
  Currency('SHP', 'St. Helena Pound', '£', 2),
  Currency('SLE', 'Sierra Leonean Leone', 'Le', 2),
  Currency('SOS', 'Somali Shilling', 'Sh', 2),
  Currency('SRD', 'Surinamese Dollar', r'$', 2),
  Currency('SSP', 'South Sudanese Pound', '£', 2),
  Currency('STN', 'São Tomé and Príncipe Dobra', 'Db', 2),
  Currency('SYP', 'Syrian Pound', 'LS', 2),
  Currency('SZL', 'Swazi Lilangeni', 'E', 2),
  Currency('THB', 'Thai Baht', '฿', 2),
  Currency('TJS', 'Tajikistani Somoni', 'SM', 2),
  Currency('TMT', 'Turkmenistani Manat', 'm', 2),
  Currency('TND', 'Tunisian Dinar', 'DT', 3),
  Currency('TOP', 'Tongan Paʻanga', r'T$', 2),
  Currency('TRY', 'Turkish Lira', '₺', 2),
  Currency('TTD', 'Trinidad & Tobago Dollar', r'TT$', 2),
  Currency('TWD', 'New Taiwan Dollar', r'NT$', 2),
  Currency('TZS', 'Tanzanian Shilling', 'TSh', 2),
  Currency('UAH', 'Ukrainian Hryvnia', '₴', 2),
  Currency('UGX', 'Ugandan Shilling', 'USh', 0),
  Currency('USD', 'US Dollar', r'$', 2),
  Currency('UYU', 'Uruguayan Peso', r'$U', 2),
  Currency('UZS', 'Uzbekistani Som', 'soʻm', 2),
  Currency('VES', 'Venezuelan Bolívar', 'Bs.', 2),
  Currency('VND', 'Vietnamese Dong', '₫', 0),
  Currency('VUV', 'Vanuatu Vatu', 'VT', 0),
  Currency('WST', 'Samoan Tala', r'WS$', 2),
  Currency('XAF', 'Central African CFA Franc', 'FCFA', 0),
  Currency('XCD', 'East Caribbean Dollar', r'EC$', 2),
  Currency('XOF', 'West African CFA Franc', 'CFA', 0),
  Currency('XPF', 'CFP Franc', 'CFPF', 0),
  Currency('YER', 'Yemeni Rial', 'YR', 2),
  Currency('ZAR', 'South African Rand', 'R', 2),
  Currency('ZMW', 'Zambian Kwacha', 'ZK', 2),
  Currency('ZWG', 'Zimbabwe Gold', 'ZiG', 2),
];

final Map<String, Currency> _byCode = {for (final c in currencies) c.code: c};

/// The currency for [code]; unknown codes fall back to 2 minor units.
Currency currencyFor(String code) =>
    _byCode[code] ?? Currency(code, code, code, 2);

/// Currencies whose code or name contains [query], ignoring case.
List<Currency> searchCurrencies(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return currencies;
  return currencies
      .where(
        (c) =>
            c.code.toLowerCase().contains(q) ||
            c.name.toLowerCase().contains(q),
      )
      .toList();
}
