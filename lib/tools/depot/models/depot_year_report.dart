/// Realized income and costs of one calendar year, net as Parqet books them.
class DepotYearReport {
  final int year;
  final double realizedGain;
  final double dividends;
  final double interest;
  final double taxes;
  final double fees;
  final int sells;

  const DepotYearReport({
    required this.year,
    this.realizedGain = 0,
    this.dividends = 0,
    this.interest = 0,
    this.taxes = 0,
    this.fees = 0,
    this.sells = 0,
  });

  double get total => realizedGain + dividends + interest;

  DepotYearReport add({
    double realizedGain = 0,
    double dividends = 0,
    double interest = 0,
    double taxes = 0,
    double fees = 0,
    int sells = 0,
  }) => DepotYearReport(
    year: year,
    realizedGain: this.realizedGain + realizedGain,
    dividends: this.dividends + dividends,
    interest: this.interest + interest,
    taxes: this.taxes + taxes,
    fees: this.fees + fees,
    sells: this.sells + sells,
  );
}
