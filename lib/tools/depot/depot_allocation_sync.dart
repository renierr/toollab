import 'depot_allocation_state.dart';
import 'depot_portfolio_state.dart';

Future<void> syncDepotAllocation(
  DepotPortfolioState portfolio,
  DepotAllocationState allocation,
) async {
  await allocation.refresh(portfolio.holdings);
}
