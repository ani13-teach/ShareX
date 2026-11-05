using System;
using System.IO;
using System.Collections.Generic;
using System.Linq;
using Mono.Cecil;
using Mono.Cecil.Cil;

public static class ShareXChinesePatch
{
    private static IEnumerable<TypeDefinition> Walk(IEnumerable<TypeDefinition> list)
    {
        foreach (var t in list) { yield return t; foreach (var n in Walk(t.NestedTypes)) yield return n; }
    }

    private static MethodDefinition Mapping(TypeDefinition owner, string name, string[] pairs, MethodReference equal)
    {
        var module = owner.Module;
        var method = new MethodDefinition(name, MethodAttributes.Assembly | MethodAttributes.Static | MethodAttributes.HideBySig, module.TypeSystem.String);
        method.Parameters.Add(new ParameterDefinition(module.TypeSystem.String));
        owner.Methods.Add(method);
        var il = method.Body.GetILProcessor();
        for (int i = 0; i < pairs.Length; i += 2)
        {
            var next = Instruction.Create(OpCodes.Nop);
            il.Emit(OpCodes.Ldarg_0);
            il.Emit(OpCodes.Ldstr, pairs[i]);
            il.Emit(OpCodes.Call, equal);
            il.Emit(OpCodes.Brfalse, next);
            il.Emit(OpCodes.Ldstr, pairs[i + 1]);
            il.Emit(OpCodes.Ret);
            il.Append(next);
        }
        il.Emit(OpCodes.Ldarg_0);
        il.Emit(OpCodes.Ret);
        return method;
    }

    private static void NormalizeArgument(MethodDefinition target, MethodDefinition mapper, int index)
    {
        var il = target.Body.GetILProcessor();
        var first = target.Body.Instructions[0];
        il.InsertBefore(first, Instruction.Create(OpCodes.Ldarg, target.Parameters[index]));
        il.InsertBefore(first, Instruction.Create(OpCodes.Call, mapper));
        il.InsertBefore(first, Instruction.Create(OpCodes.Starg, target.Parameters[index]));
    }

    public static int Apply(string input, string output, string[] keys, string[] sources, string[] translations)
    {
        var map = new Dictionary<string, int>(StringComparer.Ordinal);
        for (int i = 0; i < keys.Length; i++) map.Add(keys[i], i);
        var resolver = new DefaultAssemblyResolver();
        resolver.AddSearchDirectory(Path.GetDirectoryName(input));
        using (var assembly = AssemblyDefinition.ReadAssembly(input, new ReaderParameters { AssemblyResolver = resolver }))
        {
            var module = assembly.MainModule;
            var types = Walk(module.Types).ToArray();
            int count = 0;
            foreach (var method in types.SelectMany(t => t.Methods).Where(m => m.HasBody))
            {
                foreach (var ins in method.Body.Instructions)
                {
                    int index;
                    if (ins.OpCode != OpCodes.Ldstr || !map.TryGetValue(method.MetadataToken.ToInt32() + ":" + ins.Offset, out index)) continue;
                    if ((string)ins.Operand != sources[index]) throw new InvalidDataException("String mismatch: " + keys[index]);
                    ins.Operand = translations[index];
                    count++;
                }
            }
            if (count != map.Count) throw new InvalidDataException("Patch count mismatch.");
            var equal = types.SelectMany(t => t.Methods).Where(m => m.HasBody).SelectMany(m => m.Body.Instructions)
                .Select(i => i.Operand as MethodReference).First(m => m != null && m.DeclaringType.FullName == "System.String" && m.Name == "op_Equality");
            var helper = new TypeDefinition("ShareX.ImageEditor.Localization", "ChineseDisplay", TypeAttributes.NotPublic | TypeAttributes.Abstract | TypeAttributes.Sealed | TypeAttributes.BeforeFieldInit, module.TypeSystem.Object);
            module.Types.Add(helper);
            var categories = Mapping(helper, "Category", new[] { "Manipulations", "图像处理", "Adjustments", "颜色调整", "Filters", "滤镜", "Drawings", "绘制" }, equal);
            var display = Mapping(helper, "ThemeDisplay", new[] { "Dark", "深色", "Light", "浅色" }, equal);
            var storage = Mapping(helper, "ThemeStorage", new[] { "深色", "Dark", "浅色", "Light" }, equal);
            var category = types.Single(t => t.FullName == "ShareX.ImageEditor.Presentation.Controls.EffectCategory");
            var borderMap = Mapping(helper, "BorderDisplay", new[] { "Solid", "实线", "Dash", "虚线", "Dot", "点线" }, equal);
            var borderConverter = types.Single(t => t.FullName == "ShareX.ImageEditor.Presentation.Converters.BorderStyleDisplayConverter").Methods.Single(m => m.Name == "Convert");
            var borderText = borderConverter.Body.Instructions.Single(i => i.OpCode == OpCodes.Callvirt && i.Operand is MethodReference && ((MethodReference)i.Operand).Name == "ToString");
            borderConverter.Body.GetILProcessor().InsertAfter(borderText, Instruction.Create(OpCodes.Call, borderMap));
            NormalizeArgument(category.Methods.Single(m => m.Name == ".ctor" && m.Parameters.Count == 4), categories, 0);
            var vm = types.Single(t => t.FullName == "ShareX.ImageEditor.Presentation.ViewModels.MainViewModel");
            NormalizeArgument(vm.Methods.Single(m => m.Name == "NormalizeEditorTheme"), storage, 0);
            var getter = vm.Methods.Single(m => m.Name == "get_EditorTheme");
            var ret = getter.Body.Instructions.Last();
            getter.Body.GetILProcessor().InsertBefore(ret, Instruction.Create(OpCodes.Call, display));
            var view = types.Single(t => t.FullName == "ShareX.ImageEditor.Presentation.Views.EditorView");
            NormalizeArgument(view.Methods.Single(m => m.Name == "IsLightTheme"), storage, 0);
            assembly.Write(output);
            using (var check = AssemblyDefinition.ReadAssembly(output))
            {
                if (Walk(check.MainModule.Types).Count() != types.Length + 1) throw new InvalidDataException("Type validation failed.");
                foreach (var resource in module.Resources.OfType<EmbeddedResource>())
                {
                    var other = check.MainModule.Resources.OfType<EmbeddedResource>().Single(r => r.Name == resource.Name);
                    if (!resource.GetResourceData().SequenceEqual(other.GetResourceData())) throw new InvalidDataException("Resource validation failed.");
                }
            }
            return count;
        }
    }
}
