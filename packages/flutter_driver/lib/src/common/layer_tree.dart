import 'message.dart';

class GetLayerTree extends Command {
  const GetLayerTree({super.timeout});

  GetLayerTree.deserialize(super.json) : super.deserialize();

  @override
  String get kind => 'get_layer_tree';
}

class LayerTree extends Result {
  const LayerTree(this.tree);

  final String? tree;

  static LayerTree fromJson(Map<String, dynamic> json) {
    return LayerTree(json['tree'] as String);
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'tree': tree,
      };
}
