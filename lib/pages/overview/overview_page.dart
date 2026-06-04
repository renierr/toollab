import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tool_lab/constants.dart';
import 'package:tool_lab/core/tool_registry.dart';
import 'package:tool_lab/widgets/tool_card.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tools = ToolRegistry.all;
    return Scaffold(
      appBar: AppBar(title: Text(AppConstants.appName)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 20),
                child: Text(
                  'Your tools',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = switch (constraints.maxWidth) {
                      > 900 => 4,
                      > 600 => 3,
                      _ => 2,
                    };
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: tools.length,
                      itemBuilder: (context, index) {
                        final tool = tools[index];
                        return ToolCard(
                          tool: tool,
                          onTap: () => context.push(tool.route),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
