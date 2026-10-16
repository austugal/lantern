import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GuideTopic {
  const GuideTopic(this.title, this.keywords, this.answer, {this.template});
  final String title, keywords, answer;
  final String? template;
}

const guideTopics = <GuideTopic>[
  GuideTopic(
    'Connect two phones',
    'connect pairing bluetooth wifi wi-fi nearby android iphone ios code',
    'Open Lantern on both phones. Turn on Bluetooth and Wi-Fi, then tap Turn on Lantern. '
        'Choose the other person and confirm the invitation in person. Compare pairing codes when shown. '
        'This build connects Android to Android or iPhone to iPhone, one person at a time. '
        'Keep both apps open. A display name alone is not proof of identity.',
  ),
  GuideTopic(
    'No nearby people or lost connection',
    'troubleshoot error permission disconnected unavailable discover range reconnect',
    'Check both phones use the same platform, keep Lantern open, and enable Bluetooth and Wi-Fi. '
        'Allow the nearby or local-network permissions requested by the operating system. '
        'Move closer, then turn Lantern off and on on both phones. '
        'Android needs compatible Google Play services. Walls and interference can reduce range. '
        'Backgrounding disconnects and clears the conversation; reconnect manually.',
  ),
  GuideTopic(
    'Hotel staff handover',
    'hotel staff hospitality shift colleague reception housekeeping maintenance message handover template',
    'Use a short message with the task, location, owner and requested reply. '
        'Avoid guest names, payment data or other sensitive details. '
        'Copy this template, edit it in Conversation and send only after checking the recipient. '
        'Delivered means the other app acknowledged the message, not that your colleague read it. '
        'This preview is not a group dispatch or background staff-paging system.',
    template:
        'Shift handover\nArea: [area]\nTask: [task]\nOwner: [colleague]\nNeeded by: [time]\nPlease reply to confirm.',
  ),
  GuideTopic(
    'Location and privacy',
    'gps share location privacy consent coordinates tracking revoke stop',
    'Location sharing starts only when you choose Share for 15 minutes and confirm. '
        'It sends precise coordinates to the connected peer. Stop sharing at any time; '
        'backgrounding or disconnecting also stops it. Received positions expire after 30 seconds without updates. '
        'Local GPS under Offline navigation does not share your position. '
        'A recipient can copy what you send. Lantern cannot track a person by phone number, email or username.',
  ),
  GuideTopic(
    'Buddy check-in limits',
    'guardian sos emergency timer safety safe walk check-in checkin help',
    'Ask your connected peer to be a guardian and wait for acceptance. '
        'Choose a check-in timer, then check in before it ends. If it expires, Lantern attempts an alert over that connection. '
        'Both apps must stay open and connected. Backgrounding or disconnecting cancels the timer. '
        'SOS does not automatically start location sharing or contact emergency services. '
        'No receipt or rescue guarantee is provided; use an appropriate independent emergency channel.',
  ),
  GuideTopic(
    'Navigate without a map',
    'navigation waypoint trail breadcrumb north bearing distance gps offline map',
    'Start local GPS, wait for a fix, and save a waypoint. Read its straight-line distance and bearing clockwise from true north. '
        'The trail start helps point back to where you began. This is not turn-by-turn navigation; '
        'it cannot identify walls, hazards or safe routes. GPS can be poor indoors. '
        'Trail and waypoints are held in memory, and Clear trail removes both.',
  ),
  GuideTopic(
    'Disappearing messages',
    'expiry delete disappear lifetime message retention screenshot',
    'Set Message lifetime in Field tools before sending. It applies to new messages; '
        'existing messages keep their expiry. Disconnecting clears this conversation. '
        'Expiry cannot erase screenshots, copied text or information remembered by the recipient.',
  ),
  GuideTopic(
    'Offline guide and AI status',
    'copilot ai model assistant internet cloud online offline dependencies',
    'This guide searches built-in instructions. It works offline and sends no questions to a server. '
        'It is not generative AI and cannot inspect your phone, run commands or change settings. '
        'Online AI and an on-device language model are not configured in this build. '
        'The app still depends on its operating system, device radios and packaged software components. '
        'Offline messaging does not mean unlimited range or guaranteed delivery.',
  ),
];

List<GuideTopic> searchGuide(String query) {
  final terms = query.toLowerCase().trim().split(RegExp(r'\s+'));
  return guideTopics
      .where((topic) {
        final text = '${topic.title} ${topic.keywords} ${topic.answer}'
            .toLowerCase();
        return terms.every(text.contains);
      })
      .toList(growable: false);
}

Future<void> showOfflineGuide(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const Dialog.fullscreen(child: OfflineGuide()),
);

class OfflineGuide extends StatefulWidget {
  const OfflineGuide({super.key});
  @override
  State<OfflineGuide> createState() => _OfflineGuideState();
}

class _OfflineGuideState extends State<OfflineGuide> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final topics = searchGuide(query);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline guide'),
        leading: IconButton(
          tooltip: 'Close offline guide',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                'Built-in guidance, not AI. No network requests or automatic actions.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Search guide topics',
                  hintText: 'Connection, hotel, GPS, privacy…',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => query = value),
              ),
            ),
            Expanded(
              child: topics.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No matching built-in guidance. Try a shorter topic. This guide cannot generate answers.',
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: topics.length,
                      itemBuilder: (context, index) {
                        final topic = topics[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  topic.title,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(topic.answer),
                                if (topic.template != null) ...[
                                  const SizedBox(height: 12),
                                  SelectableText(topic.template!),
                                  TextButton.icon(
                                    icon: const Icon(Icons.copy),
                                    label: const Text('Copy handover template'),
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: topic.template!),
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Template copied. Edit and send it yourself.',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
