// node
var path = require('path');
// vendors
var program = require('commander');
// project
var restore = require('./restore');

program
  .version('1.0.0')
  .option(
    '-l, --local <path>',
    'The path to local journal'
  )
  .option(
    '-r, --remote <path>',
    'The path to remote journal'
  )
  .parse(process.argv);

if (require.main === module) {
  var local = program.local || '';
  if (local.indexOf('.') === 0) {
    local = path.join(process.cwd(), local);
  }
  var remote = program.remote || '';
  if (remote.indexOf('.') === 0) {
    remote = path.join(process.cwd(), remote);
  }
  var report = journal.create(input, {
    tmpDir: path.join(__dirname, '../../../tmp/journals'),
    withChecksum: false,
    withMetadata: false,
    withElementaryStreamMetadata: true,
    withElementaryStreamChecksum: false
  });
  var contents = JSON.stringify(report, null, 2);
  if (output) {
    fs.writeFileSync(output, contents);
  } else {
    console.log(contents);
  }
}
