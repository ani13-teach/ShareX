using Mono.Cecil;
using Mono.Cecil.Cil;
using System.Text.Json;
using System.Resources;
using System.Collections;

var mode = args[0];
var path = args[1];
using var asm = AssemblyDefinition.ReadAssembly(path);
IEnumerable<TypeDefinition> Walk(IEnumerable<TypeDefinition> types) => types.SelectMany(t => new[]{t}.Concat(Walk(t.NestedTypes)));
var types = Walk(asm.MainModule.Types).ToArray();
var options = new JsonSerializerOptions { WriteIndented = true, Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping };
if(mode == "dump") {
 var rows = types.SelectMany(t=>t.Methods.Where(m=>m.HasBody).SelectMany(m=>m.Body.Instructions.Where(i=>i.OpCode==OpCodes.Ldstr).Select(i=>new {type=t.FullName,method=m.Name,token=m.MetadataToken.ToInt32(),offset=i.Offset,text=(string)i.Operand,next=i.Next?.ToString()}))).ToArray();
 File.WriteAllText(args[2],JsonSerializer.Serialize(rows,options));
 Console.WriteLine($"{rows.Length} literals, {rows.Select(r=>r.text).Distinct().Count()} unique");
} else if(mode == "types") {
 foreach(var t in types.Where(t=>t.FullName.Contains(args[2],StringComparison.OrdinalIgnoreCase))) {
 Console.WriteLine(t.FullName);
 if(args.Length<4) foreach(var f in t.Fields) Console.WriteLine($"FIELD {f.Name} = {f.Constant}");
 foreach(var m in t.Methods.Where(m=>m.HasBody && (args.Length<4 || m.Name==args[3]))) {Console.WriteLine(m.FullName);foreach(var i in m.Body.Instructions) Console.WriteLine(i);}
 }
} else if(mode == "resources") {
 var rows = new List<object>();
 foreach(var res in asm.MainModule.Resources.OfType<EmbeddedResource>().Where(r=>r.Name.EndsWith(".resources"))) {
 using var rr = new System.Resources.Extensions.DeserializingResourceReader(res.GetResourceStream());
 var entries=rr.GetEnumerator(); while(entries.MoveNext()) { var key=(string)entries.Key; try { if(entries.Value is string s) rows.Add(new{resource=res.Name,key,text=s}); } catch(NotSupportedException) {} catch(FileNotFoundException) {} catch(TypeLoadException) {} }
 }
 File.WriteAllText(args[2],JsonSerializer.Serialize(rows,options)); Console.WriteLine(rows.Count);
} else if(mode == "patch") {
 var map=JsonSerializer.Deserialize<Dictionary<string,string>>(File.ReadAllText(args[2]))!;
 int count=0;
 foreach(var m in types.SelectMany(t=>t.Methods).Where(m=>m.HasBody)) foreach(var i in m.Body.Instructions) if(i.OpCode==OpCodes.Ldstr && map.TryGetValue($"{m.MetadataToken.ToInt32()}:{i.Offset}",out var value)) {i.Operand=value;count++;}
 asm.Write(args[3]);Console.WriteLine($"Patched {count} literals");
} else if(mode == "verify") {
 using var other=AssemblyDefinition.ReadAssembly(args[2]);
 var a=types.SelectMany(t=>t.Methods).Where(m=>m.HasBody).ToArray();
 var b=Walk(other.MainModule.Types).SelectMany(t=>t.Methods).Where(m=>m.HasBody).ToArray();
 if(a.Length!=b.Length) throw new Exception("Method count differs");
 int changes=0;
 for(int n=0;n<a.Length;n++) {
 var x=a[n].Body.Instructions;var y=b[n].Body.Instructions;
 if(x.Count!=y.Count)throw new Exception("Instruction count differs");
 for(int k=0;k<x.Count;k++) {
 if(x[k].OpCode!=y[k].OpCode)throw new Exception("Opcode differs");
 if(x[k].OpCode==OpCodes.Ldstr && (string)x[k].Operand!=(string)y[k].Operand) changes++;
 else if(x[k].Operand?.ToString()!=y[k].Operand?.ToString())throw new Exception($"Operand differs: {a[n].FullName} {x[k]} {y[k]}");
 }
 }
 foreach(var r in asm.MainModule.Resources.OfType<EmbeddedResource>()) {
 var q=other.MainModule.Resources.OfType<EmbeddedResource>().Single(q=>q.Name==r.Name);
 if(!r.GetResourceData().SequenceEqual(q.GetResourceData()))throw new Exception("Resource differs");
 }
 Console.WriteLine($"Verified {a.Length} method bodies; only {changes} string operands changed; embedded resources identical.");
}
