// `ProofEvent`/`ProofEventType` moved into `amuwak_core` (Customer App Phase C)
// so the Drift-free `LaundryOrder` and the customer app can share them. This
// re-export keeps the staff app's existing relative imports working unchanged.
export 'package:amuwak_core/models.dart' show ProofEvent, ProofEventType;
