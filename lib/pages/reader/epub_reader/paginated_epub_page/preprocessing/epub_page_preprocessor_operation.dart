import 'package:html/dom.dart' as dom;

/// A single operation applied during a preprocessor tree walk.
///
/// Operations are called in registration order for [start] and [enter], and in
/// reverse registration order for [exit] and [finish]. That ordering lets an
/// operation keep state that is scoped to the subtree it is visiting.
abstract class EpubPagePreprocessorOperation {
  /// Called once before the tree walk starts.
  void start(dom.DocumentFragment root) {}

  /// Called for every element before its children are visited.
  void enter(dom.Element element) {}

  /// Called for every element after its children have been visited.
  void exit(dom.Element element) {}

  /// Called for every text node in document order.
  void text(dom.Text text) {}

  /// Called once after the tree walk has finished.
  void finish(dom.DocumentFragment root) {}
}
