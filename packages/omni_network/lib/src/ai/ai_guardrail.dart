import 'package:meta/meta.dart';

import '../core/omni_network_exception.dart';
import 'ai_models.dart';

/// Action taken by [AiGuardrail] when sensitive or prohibited content matches
/// before sending messages to an external AI provider.
enum AiGuardrailAction {
  /// Replace matched substrings with deterministic reversible placeholders
  /// (`[EMAIL_1]`, `[PHONE_1]`, `[SECRET_1]`, …).
  mask,

  /// Reject the request immediately with a [RequestFailure].
  block,

  /// Allow through untouched (useful with custom `blockedIf` inspection).
  allow,
}

/// Configurable privacy & safety filter running before prompts leave the
/// device for external AI models (and optionally restoring masked placeholders in
/// responses).
@immutable
final class AiGuardrail {
  /// Creates an AI privacy/safety guardrail.
  const AiGuardrail({
    this.action = AiGuardrailAction.mask,
    this.maskEmails = true,
    this.maskPhones = true,
    this.maskCreditCards = true,
    this.maskSecrets = true,
    this.restoreInResponse = false,
    this.customPatterns = const {},
    this.blockedIf,
  });

  /// Preset masking emails, phones, credit cards, and common API tokens before
  /// calling cloud LLMs.
  const AiGuardrail.piiMask({bool restoreInResponse = false})
    : this(
        action: AiGuardrailAction.mask,
        maskEmails: true,
        maskPhones: true,
        maskCreditCards: true,
        maskSecrets: true,
        restoreInResponse: restoreInResponse,
      );

  /// Policy applied when built-in or [customPatterns] match.
  final AiGuardrailAction action;

  /// Masks email addresses.
  final bool maskEmails;

  /// Masks phone numbers (8–15 digits allowing separators).
  final bool maskPhones;

  /// Masks 13–19 digit payment card sequences.
  final bool maskCreditCards;

  /// Masks common API keys/JWTs (`sk-...`, `AIza...`, `ghp_...`, `eyJ...`).
  final bool maskSecrets;

  /// Replaces generated placeholders (`[EMAIL_1]`) back with original values
  /// in returned `AiResponse.text` when keeping answers local-only.
  final bool restoreInResponse;

  /// Named extra regex rules (for example `{'NID': RegExp(r'\b\d{10,17}\b')}`).
  final Map<String, RegExp> customPatterns;

  /// Optional custom predicate throwing [RequestFailure] on match when it
  /// returns `true`.
  final bool Function(String prompt)? blockedIf;

  static final RegExp _emailRe = RegExp(
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b',
  );
  static final RegExp _cardRe = RegExp(r'\b(?:\d[ -]*?){13,19}\b');
  static final RegExp _phoneRe = RegExp(
    r'(?<!\w)(?:\+?\d{1,3}[\s.-]?)?(?:\(?\d{2,4}\)?[\s.-]?)?\d{3,4}[\s.-]?\d{4}(?!\w)',
  );
  static final RegExp _secretRe = RegExp(
    r'\b(?:sk-[A-Za-z0-9_-]{16,}|AIza[0-9A-Za-z_-]{20,}|gh[pousr]_[A-Za-z0-9_]{20,}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,})\b',
  );

  /// Filters all [AiTextPart] items inside [messages], throwing
  /// [RequestFailure] when [AiGuardrailAction.block] or [blockedIf] triggers.
  ({List<AiMessage> messages, Map<String, String> placeholders}) inspectMessages(
    List<AiMessage> messages,
  ) {
    final placeholders = <String, String>{};
    var seq = 0;

    String process(String input) {
      if (blockedIf != null && blockedIf!(input)) {
        throw const RequestFailure('Prompt rejected by AI guardrail policy');
      }
      if (action == AiGuardrailAction.allow) return input;

      var out = input;
      final rules = <(String label, RegExp re)>[
        if (maskSecrets) ('SECRET', _secretRe),
        if (maskEmails) ('EMAIL', _emailRe),
        if (maskCreditCards) ('CARD', _cardRe),
        if (maskPhones) ('PHONE', _phoneRe),
        for (final entry in customPatterns.entries) (entry.key, entry.value),
      ];

      for (final (label, re) in rules) {
        if (action == AiGuardrailAction.block && re.hasMatch(out)) {
          throw RequestFailure(
            'Blocked by AI guardrail ($label detected in prompt)',
          );
        }
        out = out.replaceAllMapped(re, (m) {
          final original = m.group(0)!;
          final token = '[$label#${++seq}]';
          placeholders[token] = original;
          return token;
        });
      }
      return out;
    }

    final sanitized = <AiMessage>[];
    for (final msg in messages) {
      if (msg.parts.every((p) => p is! AiTextPart)) {
        sanitized.add(msg);
        continue;
      }
      sanitized.add(
        AiMessage(
          role: msg.role,
          name: msg.name,
          metadata: msg.metadata,
          parts: [
            for (final p in msg.parts)
              if (p is AiTextPart) AiTextPart(process(p.text)) else p,
          ],
        ),
      );
    }
    return (messages: sanitized, placeholders: placeholders);
  }

  /// Restores placeholders produced by [inspectMessages] inside model output
  /// when [restoreInResponse] is enabled.
  String restoreText(String text, Map<String, String> placeholders) {
    if (!restoreInResponse || placeholders.isEmpty) return text;
    var out = text;
    for (final e in placeholders.entries) {
      out = out.replaceAll(e.key, e.value);
    }
    return out;
  }
}
