import 'message.dart';

class GetRenderTree extends Command {
  const GetRenderTree({super.timeout});

  GetRenderTree.deserialize(super.json) : super.deserialize();

  @override
  String get kind => 'get_render_tree';
}

class RenderTree extends Result {
  const RenderTree(this.tree);

  final String? tree;

  static RenderTree fromJson(Map<String, dynamic> json) {
    return RenderTree(json['tree'] as String);
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'tree': tree,
      };
}
