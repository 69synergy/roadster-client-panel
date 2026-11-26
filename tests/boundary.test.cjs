const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const parser = require('luaparse');
// Parse UTF-8 as byte-valued code units, matching Lua string byte semantics.
const source = fs.readFileSync('src/main.client.luau').toString('latin1');
const ast = parser.parse(source, { luaVersion: '5.3', encodingMode: 'pseudo-latin1' });
function walk(node, visit) {
  if (!node || typeof node !== 'object') return;
  visit(node);
  for (const value of Object.values(node)) {
    if (Array.isArray(value)) value.forEach(n => walk(n, visit));
    else if (value && typeof value === 'object') walk(value, visit);
  }
}
const services = new Set(['Players', 'RunService', 'UserInputService', 'ReplicatedStorage']);
const methods = new Set([
  'GetService', 'WaitForChild', 'FindFirstChild', 'IsA', 'Fire', 'Destroy',
  'Connect', 'Disconnect', 'GetFocusedTextBox', 'FindFirstChildOfClass',
  'FindFirstChildWhichIsA', 'GetChildren', 'GetAttribute', 'GetAttributes', 'IsDescendantOf',
]);
const globals = new Set(['assert', 'ipairs', 'pairs', 'pcall', 'tostring']);
const functions = new Set();
walk(ast, node => {
  if (node.type === 'FunctionDeclaration' && node.identifier?.type === 'Identifier') functions.add(node.identifier.name);
});
test('source parses completely', () => assert.ok(ast.body.length > 0));
test('only approved services and locally owned event dispatch', () => {
  walk(ast, node => {
    if (node.type !== 'CallExpression' || node.base.type !== 'MemberExpression') return;
    const name = node.base.identifier.name;
    if (name === 'GetService') assert.ok(services.has(node.arguments[0]?.value));
    if (name === 'Fire') assert.equal(node.base.base.name, 'shutdown');
  });
});
test('no unreviewed calls, module execution, network or physics methods', () => {
  const dotted = new Set(['table.insert', 'table.concat', 'table.remove', 'table.sort', 'string.sub',
    'string.format', 'Instance.new', 'Color3.fromRGB', 'UDim2.new', 'UDim2.fromScale',
    'UDim2.fromOffset', 'UDim.new', 'Vector2.new', 'Vector3.new', 'CFrame.new', 'CFrame.lookAt']);
  walk(ast, node => {
    if (node.type !== 'CallExpression') return;
    const base = node.base;
    if (base.type === 'Identifier') assert.ok(globals.has(base.name) || functions.has(base.name), base.name);
    else if (base.type === 'MemberExpression' && base.indexer === ':') assert.ok(methods.has(base.identifier.name), base.identifier.name);
    else if (base.type === 'MemberExpression' && base.base.type === 'Identifier') {
      const path = `${base.base.name}.${base.identifier.name}`;
      assert.ok(dotted.has(path), path);
    } else assert.fail('Unreviewed indirect call');
  });
});
test('property writes are limited to UI, camera and local state', () => {
  const allowed = new Set(['Parent', 'Position', 'Size', 'TextColor3', 'Text', 'Visible',
    'BackgroundColor3', 'AutomaticSize', 'CanvasPosition', 'TextStrokeTransparency',
    'TextXAlignment', 'Adornee', 'CameraType', 'CameraSubject', 'FieldOfView', 'CFrame', 'Focus',
    'tab', 'camera', 'fov', 'police', 'missions']);
  walk(ast, node => {
    if (node.type !== 'AssignmentStatement') return;
    for (const target of node.variables) {
      if (target.type === 'MemberExpression') assert.ok(allowed.has(target.identifier.name), target.identifier.name);
      if (target.type === 'IndexExpression') {
        assert.ok(['object', 'pages', 'tabButtons', 'wanted', 'markers'].includes(target.base.name), 'Unreviewed indexed write');
      }
    }
  });
});
