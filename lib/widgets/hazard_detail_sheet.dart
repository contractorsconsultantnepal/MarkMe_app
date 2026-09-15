import 'package:flutter/material.dart';
import '../models/hazard_zone.dart';

Color colorForZone(ZoneColor c) {
  switch (c) {
    case ZoneColor.green:
      return Colors.green;
    case ZoneColor.yellow:
      return Colors.amber;
    case ZoneColor.blue:
      return Colors.blue;
    case ZoneColor.red:
      return Colors.red;
  }
}

/// Shows the hazard name, type, and a breakdown of every factor that
/// contributed to the zone's intensity — required so tapping a region
/// always explains *why* it's that color.
void showHazardDetailSheet(BuildContext context, HazardZone zone) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: colorForZone(zone.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(zone.color.label,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(zone.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  Chip(
                    label: Text(
                      '${zone.category.label} · ${zone.origin == HazardOrigin.natural ? "Natural" : "Artificial"}',
                    ),
                  ),
                  if (zone.isLive)
                    Chip(
                      label: const Text('LIVE'),
                      backgroundColor: Colors.green.shade100,
                      avatar: const Icon(Icons.podcasts, size: 16),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(zone.summary, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 20),
              Text('Why this zone is ${zone.color.name}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...zone.factors.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(f.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            Text('${f.contributionPercent.toStringAsFixed(0)}%'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: f.contributionPercent / 100,
                            minHeight: 6,
                            backgroundColor: Colors.grey.shade200,
                            color: colorForZone(zone.color),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          f.description,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                        Text(
                          f.isHistorical ? 'Based on past events' : 'Forecast / upcoming risk signal',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )),
              const Divider(height: 32),
              Text('Source: ${zone.source}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              if (zone.sourceUrl.isNotEmpty)
                Text('Source URL: ${zone.sourceUrl}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              Text('Last updated: ${zone.lastUpdated.toLocal()}'.split('.').first,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              if (zone.dataLagNote != null && zone.dataLagNote!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Data-lag note: ${zone.dataLagNote!}',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Confidence note: ${zone.confidenceNote}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          );
        },
      );
    },
  );
}
