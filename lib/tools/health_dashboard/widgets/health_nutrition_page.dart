import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../health_dashboard_state.dart';
import '../health_record.dart';
import '../health_value_format.dart';
import '../store/health_queries.dart';
import 'health_day_navigation.dart';
import 'health_metric_day_chart.dart';
import 'health_record_stat_item.dart';
import 'health_workout_trend_chart.dart';
import 'health_record_details_page.dart';
import 'health_source_badge.dart';

class HealthNutritionPage extends StatelessWidget {
  const HealthNutritionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HealthDashboardState>();
    final l10n = AppLocalizations.of(context);
    final day = state.selectedDay;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthDashboardNutrition)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: const HealthDayNavigation(),
          ),
          _NutritionTotalsCard(totals: state.todayNutrition),
          const SizedBox(height: 20),
          Text(
            l10n.healthDashboardCaloriesLastSevenDays,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _NutritionTrend(),
          const SizedBox(height: 20),
          Text(
            l10n.healthDashboardMealTimeline,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _NutritionDayTimeline(day: day),
          const SizedBox(height: 20),
          Text(
            l10n.healthDashboardMealsOnDay(
              MaterialLocalizations.of(context).formatMediumDate(day),
            ),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _MealsForDay(day: day),
        ],
      ),
    );
  }
}

class _NutritionTrend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<HealthDashboardState>();
    return FutureBuilder<List<List<HealthRecord>>>(
      future: Future.wait([
        for (var index = 0; index < 7; index++)
          HealthQueries.instance.recordsForDay(
            type: HealthQueries.nutritionType,
            day: state.trendDayAt(index),
          ),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final days = snapshot.data!;
        double total(List<HealthRecord> meals, String key) =>
            meals.fold<double>(
              0,
              (sum, meal) => sum + (meal.value[key] as num? ?? 0),
            );
        final values = [for (final meals in days) total(meals, 'calories')];
        if (values.every((value) => value == 0)) {
          return Text(AppLocalizations.of(context).healthDashboardNoMeals);
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: HealthWorkoutTrendChart(
              values: values,
              unit: 'kcal',
              color: AppTheme.accentAmber,
              style: HealthTrendChartStyle.line,
              endDate: state.trendWeekEnd,
              tooltipSeries: [
                HealthTrendTooltipSeries(
                  values: [for (final meals in days) total(meals, 'proteinG')],
                  unit: 'g protein',
                  color: AppTheme.accentGreen,
                ),
                HealthTrendTooltipSeries(
                  values: [
                    for (final meals in days) total(meals, 'carbohydrateG'),
                  ],
                  unit: 'g carbs',
                  color: AppTheme.accentAmber,
                ),
                HealthTrendTooltipSeries(
                  values: [for (final meals in days) total(meals, 'fatG')],
                  unit: 'g fat',
                  color: AppTheme.accentBlue,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NutritionTotalsCard extends StatelessWidget {
  final Map<String, double> totals;

  const _NutritionTotalsCard({required this.totals});

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
            _NutritionValue(
              icon: Icons.local_fire_department_rounded,
              color: AppTheme.accentAmber,
              label: l10n.healthDashboardCalories,
              value: healthValue(totals['energy'] ?? 0, 'kcal'),
            ),
            _NutritionValue(
              icon: Icons.fitness_center_rounded,
              color: AppTheme.accentGreen,
              label: l10n.healthDashboardProtein,
              value: healthValue(totals['protein'] ?? 0, 'g'),
            ),
            _NutritionValue(
              icon: Icons.grain_rounded,
              color: AppTheme.accentAmber,
              label: l10n.healthDashboardCarbohydrates,
              value: healthValue(totals['carbohydrate'] ?? 0, 'g'),
            ),
            _NutritionValue(
              icon: Icons.water_drop_outlined,
              color: AppTheme.accentBlue,
              label: l10n.healthDashboardFat,
              value: healthValue(totals['fat'] ?? 0, 'g'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionValue extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _NutritionValue({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => HealthRecordStatItem(
    icon: icon,
    color: color,
    label: label,
    value: value,
  );
}

class _MealsForDay extends StatelessWidget {
  final DateTime day;

  const _MealsForDay({required this.day});

  @override
  Widget build(BuildContext context) => FutureBuilder<List<HealthRecord>>(
    future: HealthQueries.instance.recordsForDay(
      type: HealthQueries.nutritionType,
      day: day,
    ),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final meals = snapshot.data!;
      if (meals.isEmpty) {
        return Text(AppLocalizations.of(context).healthDashboardNoMeals);
      }
      return Column(
        children: [for (final meal in meals) _MealTile(meal: meal)],
      );
    },
  );
}

class _NutritionDayTimeline extends StatelessWidget {
  final DateTime day;

  const _NutritionDayTimeline({required this.day});

  @override
  Widget build(BuildContext context) => FutureBuilder<List<HealthRecord>>(
    future: HealthQueries.instance.recordsForDay(
      type: HealthQueries.nutritionType,
      day: day,
    ),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox.shrink();
      final meals = snapshot.data!;
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
    },
  );
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
