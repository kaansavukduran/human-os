import 'package:flutter/material.dart';

import '../../app/appearance_scope.dart';
import '../../domain/settings/appearance.dart';
import '../../l10n/strings.dart';
import '../../navigation/destinations.dart';
import '../../presentation/theme/spacing.dart';
import '../../presentation/widgets/area_intro.dart';
import '../../presentation/widgets/tool_row.dart';
import '../guide/body_guide_screen.dart';
import '../guide/glossary_screen.dart';
import '../help/how_to_screen.dart';

/// Learn (U034): the area's introduction, then three ways in: the glossary,
/// the body guide and the how-to, each opening its existing page. The rows
/// keep the keys they had as Today's tools ('tool-glossary', 'tool-guide',
/// 'tool-howto'), so tests and tools find them by the same names.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    void open(Widget page) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page));
    return ListView(
      key: const ValueKey('screen-learn'),
      padding: kPagePadding,
      children: [
        const AreaIntro(area: DestinationId.learn),
        const SizedBox(height: Space.l),
        ToolRow(
          key: const ValueKey('tool-glossary'),
          title: s.glossaryTitle,
          hint: s.glossaryTileHint,
          onTap: () => open(const GlossaryScreen()),
        ),
        ToolRow(
          key: const ValueKey('tool-guide'),
          title: s.guideTitle,
          hint: s.guideTileHint,
          onTap: () => open(const BodyGuideScreen()),
        ),
        ToolRow(
          key: const ValueKey('tool-howto'),
          title: s.howToTitle,
          hint: s.howToTileHint,
          onTap: () {
            AppearanceScope.read(context)?.visit(DiscoveryStep.howTo);
            open(const HowToScreen());
          },
        ),
      ],
    );
  }
}
