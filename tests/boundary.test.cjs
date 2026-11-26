const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const parser = require('luaparse');
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
test('entire generated bundle parses', () => assert.ok(ast.body.length > 0));
test('no guessed remote calls, hooks or game module execution', () => {
  const forbidden = new Set(['FireServer', 'InvokeServer', 'Invoke', 'require', 'hookmetamethod',
    'hookfunction', 'getrawmetatable', 'sethiddenproperty', 'fireproximityprompt', 'firesignal']);
  walk(ast, node => {
    if (node.type === 'Identifier') assert.ok(!forbidden.has(node.name), node.name);
    if (node.type === 'CallExpression' && node.base.type === 'MemberExpression' && node.base.identifier.name === 'Fire') {
      assert.equal(node.base.base.name, 'signal');
    }
  });
});
test('only documented stable Rayfield endpoint is downloaded by our source', () => {
  let count = 0;
  walk(ast, node => {
    if (node.type === 'CallExpression' && node.base.type === 'MemberExpression' && node.base.identifier.name === 'HttpGet') {
      count++;
      assert.equal(node.arguments[0].value, 'https://sirius.menu/gen2');
    }
  });
  assert.equal(count, 1);
});
test('physics mutations have explicit targets; no server container access', () => {
  walk(ast, node => {
    if (node.type === 'StringLiteral') assert.ok(!['ServerStorage', 'ServerScriptService'].includes(node.value));
    if (node.type !== 'AssignmentStatement') return;
    for (const target of node.variables) {
      if (target.type === 'MemberExpression' && ['AssemblyLinearVelocity', 'AssemblyAngularVelocity'].includes(target.identifier.name)) {
        assert.equal(target.base.name, 'chassis');
      }
    }
  });
});
