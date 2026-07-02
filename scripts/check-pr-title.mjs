#!/usr/bin/env node

const title = process.argv.slice(2).join(' ').trim();
const allowedTypes = [
  'feat',
  'fix',
  'perf',
  'refactor',
  'docs',
  'test',
  'build',
  'ci',
  'chore',
  'revert',
  'style',
];

const scope = String.raw`(?:\([a-z0-9][a-z0-9._/-]*\))?`;
const breaking = String.raw`!?`;
const subject = String.raw` [^\s].{0,119}`;
const conventionalTitle = new RegExp(
  `^(${allowedTypes.join('|')})${scope}${breaking}:${subject}$`,
);

if (!title) {
  console.error('PR title is required.');
  process.exit(1);
}

if (!conventionalTitle.test(title)) {
  console.error(`Invalid PR title: ${title}`);
  console.error('');
  console.error(
    'Use a Conventional Commit title so squash merges stay readable by Release Please.',
  );
  console.error(`Allowed types: ${allowedTypes.join(', ')}`);
  console.error('');
  console.error('Examples:');
  console.error('  feat: add endpoint inventory export');
  console.error('  fix(submission): retry transient webhook failures');
  console.error('  chore: release 1.2.3');
  process.exit(1);
}
