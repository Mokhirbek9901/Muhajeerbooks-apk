'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const sections=require('../personal-assistant/workspaces.js');

test('all four workspaces have distinct roots and concise labels',()=>{
  assert.deepEqual(sections.MODES_ORDER,['reading','costs','products','finance']);
  const roots=sections.MODES_ORDER.map(key=>sections.rootView(key));
  assert.deepEqual(roots,['home','book-costs','korea-products','finance']);
  assert.equal(new Set(roots).size,4);
});

test('reading statistics and finance statistics never mix routes',()=>{
  for(const view of ['home','library','detail','stats','calendar','categories'])
    assert.equal(sections.modeOfView(view),'reading');
  assert.equal(sections.modeOfView('finance'),'finance');
  assert.equal(sections.modeOfView('book-costs'),'costs');
  assert.equal(sections.modeOfView('korea-products'),'products');
  assert.equal(sections.modeOfView('profile'),null);
});

test('unknown saved workspace falls back to reading; profile stays shared',()=>{
  assert.equal(sections.safeMode('unexpected'),'reading');
  assert.equal(sections.safeMode(null),'reading');
  assert.equal(sections.safeMode('__proto__'),'reading');
  assert.equal(sections.navTab('products','profile',{productView:'entry'}),'profile');
  assert.equal(sections.navTab('finance','profile',{financeView:'history'}),'profile');
});

test('each workspace has its own selected navigation tab',()=>{
  assert.equal(sections.navTab('reading','library'),'library');
  assert.equal(sections.navTab('reading','stats'),'stats');
  assert.equal(sections.navTab('costs','book-costs',{costView:'main'}),'main');
  assert.equal(sections.navTab('costs','book-costs',{costView:'entry'}),'entry');
  assert.equal(sections.navTab('costs','book-costs',{costView:'report'}),'report');
  assert.equal(sections.navTab('costs','book-costs',{costView:'settings'}),'settings');
  assert.equal(sections.navTab('products','korea-products',{productView:'list'}),'list');
  assert.equal(sections.navTab('products','korea-products',{productView:'stats'}),'stats');
  assert.equal(sections.navTab('finance','finance',{financeView:'stats'}),'stats');
  assert.equal(sections.navTab('finance','finance',{financeView:'history'}),'history');
});
