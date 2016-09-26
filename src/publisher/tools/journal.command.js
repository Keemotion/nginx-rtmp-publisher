// node
var fs = require('fs');
var path = require('path');
// vendors
var program = require('commander');
// project
var journal = require('./journal');

program
  .version('1.0.0')
  .option(
    '-i, --input <path>',
    'Input directory where mpeg-ts segments are stored, playlist file name as stream name'
  )
  .option(
    '-o, --output [path]',
    'Output directory where mpeg-ts segments journal is to be written'
  )
  .parse(process.argv);

if (require.main === module) {
  var input = program.input || '';
  if (input.indexOf('.') === 0) {
    input = path.join(process.cwd(), input);
  }
  var output = program.output || '';
  if (output.indexOf('.') === 0) {
    output = path.join(process.cwd(), output);
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
