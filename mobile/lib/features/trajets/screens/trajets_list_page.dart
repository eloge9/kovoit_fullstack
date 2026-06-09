import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/trajet_provider.dart';
import '../../../shared/widgets/trajet_card.dart';

class TrajetsListPage extends ConsumerStatefulWidget {
  final bool isMesTrajets;

  const TrajetsListPage({super.key, this.isMesTrajets = false});

  @override
  ConsumerState<TrajetsListPage> createState() => _TrajetsListPageState();
}

class _TrajetsListPageState extends ConsumerState<TrajetsListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isMesTrajets) {
        ref.read(trajetsProvider.notifier).loadMesTrajets();
      } else {
        ref.read(trajetsProvider.notifier).loadTrajets();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trajetsProvider);
    final prefix = widget.isMesTrajets ? '/conducteur' : '/passager';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isMesTrajets ? 'Mes trajets' : 'Trajets disponibles'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (widget.isMesTrajets) {
            await ref.read(trajetsProvider.notifier).loadMesTrajets();
          } else {
            await ref.read(trajetsProvider.notifier).loadTrajets();
          }
        },
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(state.error!),
                        TextButton(
                          onPressed: () => widget.isMesTrajets
                              ? ref.read(trajetsProvider.notifier).loadMesTrajets()
                              : ref.read(trajetsProvider.notifier).loadTrajets(),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  )
                : state.trajets.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.directions_car_outlined, size: 80, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('Aucun trajet disponible',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: state.trajets.length,
                        itemBuilder: (context, i) {
                          final t = state.trajets[i];
                          return TrajetCard(
                            trajet: t,
                            onTap: () => context.push('$prefix/trajet/${t.id}'),
                            showActions: widget.isMesTrajets,
                            onCommencer: widget.isMesTrajets && t.statut == 'ouvert'
                                ? () async {
                                    await ref
                                        .read(trajetsProvider.notifier)
                                        .commencerTrajet(t.id);
                                  }
                                : null,
                            onTerminer: widget.isMesTrajets && t.statut == 'en_cours'
                                ? () async {
                                    await ref
                                        .read(trajetsProvider.notifier)
                                        .terminerTrajet(t.id);
                                  }
                                : null,
                          );
                        },
                      ),
      ),
      floatingActionButton: widget.isMesTrajets
          ? FloatingActionButton(
              onPressed: () => context.push('/conducteur/create-trajet'),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
