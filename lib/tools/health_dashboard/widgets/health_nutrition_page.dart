import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../health_dashboard_state.dart';
import '../health_record.dart';
import 'package:tool_lab/helpers/health_value_format.dart';
import '../store/health_metric_series.dart';
import '../store/health_queries.dart';
import 'health_day_navigation.dart';
import 'health_metric_day_chart.dart';
import 'health_metric_summary_section.dart';
import 'health_record_stat_item.dart';
import 'package:tool_lab/widgets/metric_trend_chart.dart';
import 'health_record_details_page.dart';
import 'health_source_badge.dart';

double _total(List<HealthRecord> meals, String key) =>
    meals.fold<double>(0, (sum, meal) => sum + (meal.value[key] as num? ?? 0));

/// One load of the whole trend window feeds every section, so day navigation
/// moves the totals, the timeline and the meal list together.
class HealthNutritionPage extends StatelessWidget {
  const HealthNutritionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HealthDashboardState>();
    final l10n = AppLocalizations.of(context);
    final day = state.selectedDay;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthDashboardNutrition)),
      body: FutureBuilder<List<List<HealthRecord>>>(
        future: Future.wait([
          for (var index = 0; index < 7; index++)
            HealthQueries.instance.recordsForDay(
              type: HealthQueries.nutritionType,
              day: state.trendDayAt(index),
            ),
        ]),
        builder: (context, snapshot) {
          final days = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Align(
                alignment: Alignment.centerRight,
                child: HealthDayNavigation(),
              ),
              if (days == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _NutritionTotalsCard(meals: days.last),
                const SizedBox(height: 16),
                HealthMetricSummarySection(
                  series: _caloriesSeries(state, days),
                  unit: 'kcal',
                  color: AppTheme.accentAmber,
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.healthDashboardCaloriesLastSevenDays,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                _NutritionTrend(days: days),
                const SizedBox(height: 20),
                Text(
                  l10n.healthDashboardMealTimeline,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                _NutritionDayTimeline(meals: days.last),
                const SizedBox(height: 20),
                Text(
                  l10n.healthDashboardMealsOnDay(
                    MaterialLocalizations.of(context).formatMediumDate(day),
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                _MealsForDay(meals: days.last),
              ],
            ],
          );
        },
      ),
    );
  }

  HealthMetricSeries _caloriesSeries(
    HealthDashboardState state,
    List<List<HealthRecord>> days,
  ) => HealthMetricSeries(
    sum: true,
    days: [
      for (var index = 0; index < days.length; index++)
        HealthMetricDay(
          day: state.trendDayAt(index),
          value: days[index].isEmpty ? null : _total(days[index], 'calories'),
          count: days[index].length,
        ),
    ],
  );
}

class _NutritionTrend extends StatelessWidget {
  final List<List<HealthRecord>> days;

  const _NutritionTrend({required this.days});

  @override
  Widget build(BuildContext context) {
    final state = context.read<HealthDashboardState>();
    final values = [for (final meals in days) _total(meals, 'calories')];
    if (values.every((value) => value == 0)) {
      return Text(AppLocalizations.of(context).healthDashboardNoMeals);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: MetricTrendChart(
          values: values,
          unit: 'kcal',
          color: AppTheme.accentAmber,
          style: MetricTrendChartStyle.line,
          endDate: state.trendWeekEnd,
          onDayTap: (index) => state.selectDay(state.trendDayAt(index)),
          tooltipSeries: [
            MetricTrendTooltipSeries(
              values: [for (final meals in days) _total(meals, 'proteinG')],
              unit: 'g protein',
              color: AppTheme.accentGreen,
            ),
            MetricTrendTooltipSeries(
              values: [
                for (final meals in days) _total(meals, 'carbohydrateG'),
              ],
              unit: 'g carbs',
              color: AppTheme.accentAmber,
            ),
            MetricTrendTooltipSeries(
              values: [for (final meals in days) _total(meals, 'fatG')],
              unit: 'g fat',
              color: AppTheme.accentBlue,
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionTotalsCard extends StatelessWidget {
  final List<HealthRecord> meals;

  const _NutritionTotalsCard({required this.meals});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 16,
          children: [
            HealthRecordStatItem(
              icon: Icons.local_fire_department_rounded,
              color: AppTheme.accentAmber,
              label: l10n.healthDashboardCalories,
              value: healthValue(_total(meals, 'calories'), 'kcal'),
            ),
            HealthRecordStatItem(
              icon: Icons.fitness_center_rounded,
              color: AppTheme.accentGreen,
              label: l10n.healthDashboardProtein,
              value: healthValue(_total(meals, 'proteinG'), 'g'),
            ),
            HealthRecordStatItem(
              icon: Icons.grain_rounded,
              color: AppTheme.accentAmber,
              label: l10n.healthDashboardCarbohydrates,
              value: healthValue(_total(meals, 'carbohydrateG'), 'g'),
            ),
            HealthRecordStatItem(
              icon: Icons.water_drop_outlined,
              color: AppTheme.accentBlue,
              label: l10n.healthDashboardFat,
              value: healthValue(_total(meals, 'fatG'), 'g'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealsForDay extends StatelessWidget {
  final List<HealthRecord> meals;

  const _MealsForDay({required this.meals});

  @override
  Widget build(BuildContext context) {
    if (meals.isEmpty) {
      return Text(AppLocalizations.of(context).healthDashboardNoMeals);
    }
    return Column(children: [for (final meal in meals) _MealTile(meal: meal)]);
  }
}

class _NutritionDayTimeline extends StatelessWidget {
  final List<HealthRecord> meals;

  const _NutritionDayTimeline({required this.meals});

  @override
  Widget build(BuildContext context) {
    if (meals.length < 2) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: HealthMetricDayChart(
          readings: [
            for (final meal in meals)
              (
                t: meal.startTime,
                v: (meal.value['calories'] as num? ?? 0).toDouble(),
              ),
          ],
          unit: 'kcal',
          color: AppTheme.accentAmber,
          sum: true,
        ),
      ),
    );
  }
}

class _MealTile extends StatelessWidget {
  final HealthRecord meal;

  const _MealTile({required this.meal});

  @override
  Widget build(BuildContext context) {
    final macros =
        '${healthValue(meal.value['proteinG'] as num? ?? 0, 'g')} P  · ${healthValue(meal.value['carbohydrateG'] as num? ?? 0, 'g')} C  · ${healthValue(meal.value['fatG'] as num? ?? 0, 'g')} F';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.restaurant_rounded),
        title: Text(
          meal.value['foodName'] as String? ??
              AppLocalizations.of(context).healthDashboardMeal,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(macros),
            HealthSourceBadge(packageName: meal.sourceName),
          ],
        ),
        trailing: Text(
          healthValue(meal.value['calories'] as num? ?? 0, 'kcal'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => HealthRecordDetailsPage(record: meal),
          ),
        ),
      ),
    );
  }
}
