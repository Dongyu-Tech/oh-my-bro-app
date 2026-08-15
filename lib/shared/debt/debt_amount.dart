/// Parse the debt composer's amount field.
///
/// Blank is meaningful rather than invalid: it means "I don't know the number,
/// let them fill it in", which the negotiation supports directly. So an empty
/// field is null, while junk and non-positive values are rejected — a debt of
/// zero or minus five is not something either side could sensibly confirm.
int? parseOptionalAmount(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final value = int.tryParse(trimmed);
  if (value == null || value <= 0) {
    throw FormatException('not a positive amount', raw);
  }
  return value;
}
