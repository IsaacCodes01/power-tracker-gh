import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/outage_report.dart';
import '../../models/app_user.dart';
import '../../models/notification_item.dart';
import '../../widgets/outage_card.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/admin_mode_toggle.dart';
import '../outage/outage_list_screen.dart' show ReportFilter;
import '../notifications/notifications_list_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onNavigateToReport;
  final void Function(ReportFilter? filter) onNavigateToOutages;

  const HomeScreen({
    super.key,
    required this.onNavigateToReport,
    required this.onNavigateToOutages,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _cardPageController = PageController();
  final PageController _activeLocController = PageController();
  final PageController _resolvedLocController = PageController();
  final PageController _announcementPageController = PageController();
  int _currentCard = 0;
  int _currentAnnouncement = 0;
  Timer? _cardTimer;
  Timer? _activeTimer;
  Timer? _resolvedTimer;

  // Track the last list lengths we started tickers for, so we don't
  // cancel/restart the animation on every single Firestore snapshot.
  int _activeTickerLen = -1;
  int _resolvedTickerLen = -1;

  // Streams are created once here instead of inline in build(), so
  // StreamBuilder keeps the same subscription across every rebuild
  // (setState from timers, ticker animations, etc). Recreating the
  // stream on every build was causing StreamBuilder to drop back to
  // ConnectionState.waiting repeatedly, which was the screen "blink".
  final _firestoreService = FirestoreService();
  late final Stream<List<OutageReport>> _reportsStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream;
  Stream<List<NotificationItem>>? _notifStream;

  @override
  void initState() {
    super.initState();

    _reportsStream = _firestoreService.streamReports();
    final uid = AuthService().currentUser?.uid;
    if (uid != null) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots();
      _notifStream = _firestoreService.streamNotifications(uid);
    }

    _startCardTimer();
  }

  // Pulled into its own method so we can pause/resume it around manual
  // swipes without duplicating the Timer.periodic body.
  void _startCardTimer() {
    _cardTimer?.cancel();
    _cardTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_cardPageController.hasClients) {
        int next = (_currentCard + 1) % 3;
        _cardPageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _startActiveTicker(int len) {
    if (len == _activeTickerLen) return;
    _activeTickerLen = len;
    _activeTimer?.cancel();
    if (len <= 1) return;
    _activeTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_activeLocController.hasClients) {
        int curr = _activeLocController.page?.round() ?? 0;
        int next = (curr + 1) % len;
        _activeLocController.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _startResolvedTicker(int len) {
    if (len == _resolvedTickerLen) return;
    _resolvedTickerLen = len;
    _resolvedTimer?.cancel();
    if (len <= 1) return;
    _resolvedTimer = Timer.periodic(
      const Duration(seconds: 2, milliseconds: 300),
      (_) {
        if (_resolvedLocController.hasClients) {
          int curr = _resolvedLocController.page?.round() ?? 0;
          int next = (curr + 1) % len;
          _resolvedLocController.animateToPage(
            next,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      },
    );
  }

  // Called on pointer-up after a manual swipe on the resolved locations
  // list, to hand control back to the auto-ticker from wherever the user
  // left off. Bypasses _startResolvedTicker's length-cache (which exists
  // to avoid restarting on every Firestore snapshot) since we always want
  // this to actually resume ticking.
  void _resumeResolvedTicker(int len) {
    _resolvedTimer?.cancel();
    if (len <= 1) return;
    _resolvedTimer = Timer.periodic(
      const Duration(seconds: 2, milliseconds: 300),
      (_) {
        if (_resolvedLocController.hasClients) {
          int curr = _resolvedLocController.page?.round() ?? 0;
          int next = (curr + 1) % len;
          _resolvedLocController.animateToPage(
            next,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _cardTimer?.cancel();
    _activeTimer?.cancel();
    _resolvedTimer?.cancel();
    _cardPageController.dispose();
    _activeLocController.dispose();
    _resolvedLocController.dispose();
    _announcementPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: null,
        flexibleSpace: SafeArea(
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Positioned(
                left: 16,
                child: Text(
                  'Home',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              const Align(
                alignment: Alignment.center,
                child: AdminModeToggle(),
              ),
              const Positioned(right: 8, child: NotificationBell()),
            ],
          ),
        ),
      ),
      body: StreamBuilder<List<OutageReport>>(
        stream: _reportsStream,
        builder: (context, reportSnap) {
          if (reportSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (reportSnap.hasError) {
            return Center(child: Text('Error: ${reportSnap.error}'));
          }

          final reports = reportSnap.data ?? [];
          final activeReports = reports
              .where((r) => r.status != OutageStatus.restored)
              .toList();
          final resolvedReports = reports.where((r) {
            if (r.status != OutageStatus.restored) return false;
            if (r.endTime == null) return false;
            return DateTime.now().difference(r.endTime!).inHours < 24;
          }).toList();

          final activeCount = activeReports.length;
          final resolvedCount = resolvedReports.length;
          final activeLocations = activeReports.map((e) => e.area).toList();
          final resolvedLocations = resolvedReports.map((e) => e.area).toList();

          // Only the 3 most recent reports, since Home is a quick glance.
          final recentReports = reports.take(3).toList();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startActiveTicker(activeLocations.length);
            _startResolvedTicker(resolvedLocations.length);
          });

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greet the user by first name, pulled live from their
                // Firestore profile so it updates if they edit it.
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _userStream,
                  builder: (context, userSnapshot) {
                    String greetingName = '';
                    if (userSnapshot.hasData &&
                        userSnapshot.data != null &&
                        userSnapshot.data!.exists) {
                      final appUser = AppUser.fromMap(
                        userSnapshot.data!.data()!,
                      );
                      greetingName = appUser.greetingName;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greetingName.isNotEmpty
                              ? 'Welcome, $greetingName'
                              : 'Welcome',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Power Overview',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Wrapping the carousel in a Listener so we can pause the
                // auto-slide timer while the user's finger is down. Without
                // this, the periodic animateToPage() call was fighting
                // manual drag gestures and swallowing swipes.
                Listener(
                  onPointerDown: (_) => _cardTimer?.cancel(),
                  onPointerUp: (_) => _startCardTimer(),
                  onPointerCancel: (_) => _startCardTimer(),
                  child: SizedBox(
                    height: 170,
                    child: PageView(
                      controller: _cardPageController,
                      onPageChanged: (i) => setState(() => _currentCard = i),
                      children: [
                        _buildActiveSliderCard(
                          activeCount: activeCount,
                          locations: activeLocations,
                        ),
                        _buildResolvedSliderCard(
                          resolvedCount: resolvedCount,
                          locations: resolvedLocations,
                        ),
                        _buildAnnouncementCard(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentCard == i ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentCard == i
                            ? Colors.deepPurple
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepPurple[50],
                      child: const Icon(
                        Icons.add_alert,
                        color: Colors.deepPurple,
                      ),
                    ),
                    title: const Text(
                      'File a New Report',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Report a sudden blackout or transformer issue instantly',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: widget.onNavigateToReport,
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Reported Outages',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => widget.onNavigateToOutages(null),
                      child: const Text(
                        'See All',
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (recentReports.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No outages reported yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  ...recentReports.map((report) => OutageCard(report: report)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnnouncementCard() {
    if (_notifStream == null) {
      return _buildSimpleCard(
        title: 'Announcement',
        value: 'Login',
        icon: Icons.campaign,
        color: Colors.orange,
      );
    }
    return StreamBuilder<List<NotificationItem>>(
      stream: _notifStream,
      builder: (context, snap) {
        final notifs = snap.data ?? [];
        final latest = notifs
            .where(
              (n) =>
                  n.type == NotificationType.announcement ||
                  n.type == NotificationType.maintenance,
            )
            .toList();
        latest.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Keep the swipe position valid if the list shrinks (or grows)
        // between snapshots while the card is on screen.
        if (_currentAnnouncement >= latest.length) {
          _currentAnnouncement = latest.isEmpty ? 0 : latest.length - 1;
        }
        final current = latest.isNotEmpty ? latest[_currentAnnouncement] : null;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationsListScreen(),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF6C00), Color(0xFFFFA000)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        current?.type == NotificationType.maintenance
                            ? Icons.build
                            : Icons.campaign,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      current?.type == NotificationType.maintenance
                          ? 'Maintenance'
                          : 'Announcement',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    // How many are queued up — only shown once there's
                    // more than one to swipe through.
                    if (latest.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          '${_currentAnnouncement + 1}/${latest.length}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white54,
                      size: 18,
                    ),
                  ],
                ),
                Expanded(
                  child: latest.isEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: const [
                            Text(
                              'No announcements',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'You will see official ECG updates here.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      : PageView.builder(
                          // Vertical, same axis as the location tickers on
                          // the other two cards — keeps it from fighting
                          // the outer horizontal card carousel's own drag
                          // gesture.
                          controller: _announcementPageController,
                          scrollDirection: Axis.vertical,
                          itemCount: latest.length,
                          onPageChanged: (i) =>
                              setState(() => _currentAnnouncement = i),
                          itemBuilder: (_, i) {
                            final ann = latest[i];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  ann.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  ann.message,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            );
                          },
                        ),
                ),
                // Dot indicators, same style as the outer card carousel's —
                // only rendered when there's actually something to swipe
                // between, so a single announcement stays dot-free.
                if (latest.length > 1) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      latest.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _currentAnnouncement == i ? 14 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentAnnouncement == i
                              ? Colors.white
                              : Colors.white38,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveSliderCard({
    required int activeCount,
    required List<String> locations,
  }) {
    return GestureDetector(
      onTap: () => widget.onNavigateToOutages(ReportFilter.noLight),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
          ),
          borderRadius: BorderRadius.circular(24),
          // Box shadow removed per request.
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.flash_off,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Active Outages',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  '$activeCount ${activeCount == 1 ? 'location' : 'locations'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Container(width: 1, height: 80, color: Colors.white24),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 90,
                child: locations.isEmpty
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'No active outages',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : PageView.builder(
                        controller: _activeLocController,
                        scrollDirection: Axis.vertical,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: locations.length,
                        itemBuilder: (_, i) => Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  locations[i],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  Widget _buildResolvedSliderCard({
    required int resolvedCount,
    required List<String> locations,
  }) {
    return GestureDetector(
      onTap: () => widget.onNavigateToOutages(ReportFilter.restored),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bolt, color: Colors.green, size: 20),
                ),
                const Spacer(),
                const Text(
                  'Past 24H Resolved',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                Text(
                  '$resolvedCount ${resolvedCount == 1 ? 'location' : 'locations'}',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Container(width: 1, height: 80, color: Colors.grey.shade300),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 90,
                child: locations.isEmpty
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'No resolved\nin 24h',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      )
                    : Listener(
                        // Pause the auto-tick while the user's finger is on
                        // the list, resume from wherever they left it —
                        // same pattern as the outer card carousel's timer.
                        onPointerDown: (_) => _resolvedTimer?.cancel(),
                        onPointerUp: (_) =>
                            _resumeResolvedTicker(locations.length),
                        onPointerCancel: (_) =>
                            _resumeResolvedTicker(locations.length),
                        child: PageView.builder(
                          controller: _resolvedLocController,
                          scrollDirection: Axis.vertical,
                          itemCount: locations.length,
                          itemBuilder: (_, i) => Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    locations[i],
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
