import 'market_data/onvista_api.dart';
import 'market_data/yahoo_finance_api.dart';
import 'models/market_quote.dart';
import 'parsing/security_parser.dart';

/// Yahoo quotes by symbol; a bond, which Yahoo does not list, is kept under
/// its ISIN and quoted by onvista.
class DepotMarketQuotes {
  DepotMarketQuotes._();

  static bool isBondSymbol(String symbol) => SecurityParser.isValidIsin(symbol);

  static Future<MarketQuote> intraday(String symbol) => isBondSymbol(symbol)
      ? OnvistaApi.bondQuote(symbol)
      : YahooFinanceApi.intradayQuote(symbol);

  static Future<MarketQuote> yearDaily(String symbol) => isBondSymbol(symbol)
      ? OnvistaApi.bondQuote(symbol)
      : YahooFinanceApi.yearDailyQuote(symbol);
}
