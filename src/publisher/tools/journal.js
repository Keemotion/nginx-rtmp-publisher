// node
var fs = require('fs');
var os = require('os');
var path = require('path');
var spawnSync = require('child_process').spawnSync;
// vendors
var glob = require('glob');
var tmp = require('tmp');
var mkdirp = require('mkdirp').sync;
var execute = function(execobj) {
  var args = execobj.args || [];
  var program = execobj.program;
  var commandLine = [program].concat(args).join(' ');
  // console.log(commandLine);
  var spawn = spawnSync(program, args);
  if (spawn.error) {
    throw spawn.error;
  }
  if (spawn.status !== 0) {
    throw new Error(spawn.stderr ? spawn.stderr.toString() : 'Execution error - no stderr');
  }
  return spawn.stdout.toString();
};
var decoderFormats = { aac: 'ac3', h264: 'h264' };

function checksum(filePath) {
  var command = [
    path.resolve(filePath),
  ];
  // extract the streams
  var output = execute({
    program: 'sha1sum',
    args: command
  }).toString().split(' ')[0].substr(1);
  return output;
}

function metadata(segmentPath) {
  var streamName = path.basename(segmentPath, '.ts');
  var command = [
    '-v', 'quiet',
    '-show_format',
    '-show_streams',
    '-print_format', 'json',
    path.resolve(segmentPath),
  ];
  // extract the streams
  var metadata = execute({
    program: 'ffprobe',
    args: command
  }).toString();
  var result = JSON.parse(metadata);
  var streams = result.streams;
  result.streams = {
    audio: null,
    video: null,
  };
  streams.forEach(function(stream) {
    if (stream.codec_type === 'audio') {
      delete stream.codec_type;
      result.streams.audio = stream;
    } else if (stream.codec_type === 'video') {
      delete stream.codec_type;
      result.streams.video = stream;
    }
    if (typeof stream.sample_rate !== 'undefined') stream.sample_rate = Number(stream.sample_rate);
    if (typeof stream.start_pts !== 'undefined') stream.start_pts = Number(stream.start_pts);
    if (typeof stream.start_time !== 'undefined') stream.start_time = Number(stream.start_time);
    if (typeof stream.duration !== 'undefined') stream.duration = Number(stream.duration);
    if (typeof stream.bits_per_raw_sample !== 'undefined') stream.bits_per_raw_sample = Number(stream.bits_per_raw_sample);
    
    delete stream.disposition;
  });
  delete result.format.nb_streams;
  delete result.format.nb_programs;
  delete result.format.filename;
  // casting
  if (typeof result.format.start_time !== 'undefined') result.format.start_time = Number(result.format.start_time);
  if (typeof result.format.duration !== 'undefined') result.format.duration = Number(result.format.duration);
  if (typeof result.format.size !== 'undefined') result.format.size = Number(result.format.size);
  if (typeof result.format.bit_rate !== 'undefined') result.format.bit_rate = Number(result.format.bit_rate);
  return result;
}

function extractElementaryStreams(segmentPath, defaultMetadata, opts) {
  var options = {
    tmpDir: opts ? (opts.tmpDir || os.tmpdir()) : os.tmpdir(),
  };
  var segmentMetadata = defaultMetadata || metadata(segmentPath);
  var streamName = path.basename(segmentPath, '.ts');
  var command = [
    '-y',
    '-i', path.resolve(segmentPath),
  ];
  var result = {};
  var audioStreamPath = null;
  var videoStreamPath = null;
  // ensure temp directory
  mkdirp(options.tmpDir);
  if (segmentMetadata.streams.audio) {
    audioStreamPath = path.join(options.tmpDir, 'audio.' + segmentMetadata.streams.audio.codec_name);
    command = command.concat([
      '-f', decoderFormats[segmentMetadata.streams.audio.codec_name],
      '-c:a', 'copy',
      '-c:v', 'none',
      audioStreamPath,
    ]);
    result.audio = audioStreamPath;
  }
  if (segmentMetadata.streams.video) {
    videoStreamPath = path.join(options.tmpDir, 'video.' + segmentMetadata.streams.video.codec_name);
    command = command.concat([
      '-f', decoderFormats[segmentMetadata.streams.video.codec_name],
      '-c:a', 'none',
      '-c:v', 'copy',
      videoStreamPath,
    ]);
    result.video = videoStreamPath;
  }
  execute({
    program: 'ffmpeg',
    args: command
  }).toString();
  // extract additional info after ES exist
  return result;
}

function create(inputDirectory, opts) {
  var options = {
    tmpDir: opts ? (opts.tmpDir || os.tmpdir()) : os.tmpdir(),
    withChecksum: opts ? (opts.withChecksum || false) : false,
    withMetadata: opts ? (opts.withMetadata || false) : false,
    withElementaryStreamMetadata: opts ? (opts.withElementaryStreamMetadata || false) : false,
    withElementaryStreamChecksum: opts ? (opts.withElementaryStreamChecksum || false) : false,
  }
  var playlistsJournal = {};
  // internals
  var playlistPattern = path.join(inputDirectory, '*.m3u8');
  var playlists = glob.sync(playlistPattern);
  // segments sorter is using the numeric part representing segementing cut timestamp
  var sorter = function(a, b) {
    var time_a = Number(path.basename(a, '.ts').split('-')[2]);
    var time_b = Number(path.basename(b, '.ts').split('-')[2]);
    return time_a > time_b;
  };
  // traverse each playlist and stat the files
  playlists.forEach(function(playlistPath) {
    // stream name is the playlist name without extension
    var stream = path.basename(playlistPath, '.m3u8');
    // list all segments from this stream
    var segmentsPattern = path.join(inputDirectory, stream + '*.ts');
    var segmentsList = glob.sync(segmentsPattern).sort(sorter);
    var segmentsInfo = segmentsList.map(function(segment, index) {
      // console.log(segment, index, segmentsList.length);
      var stream = path.basename(segment, '.ts');
      var stat = fs.lstatSync(segment);
      var info = {
        size: stat.size,
        file: path.basename(segment),
        time: Number(stream.split('-')[2]),
      };
      if (options.withChecksum) {
        info.checksum = checksum(segment);
      }
      if (options.withMetadata) {
        info.metadata = metadata(segment);
      }
      if (info.metadata && options.withElementaryStreamMetadata) {
        var esinfo = extractElementaryStreams(segment, info.metadata, {
          // ensure no collision
          tmpDir: path.join(options.tmpDir, stream),
        });
        if (esinfo.audio) {
          info.metadata.streams.audio.elementary = {
            metadata: metadata(esinfo.audio).streams.audio,
          };
          if (options.withElementaryStreamChecksum) {
            info.metadata.streams.audio.elementary.checksum = checksum(esinfo.audio);
          }
        }
        if (esinfo.video) {
          info.metadata.streams.video.elementary = {
            checksum: checksum(esinfo.video),
            metadata: metadata(esinfo.video).streams.video,
          };
          if (options.withElementaryStreamChecksum) {
            info.metadata.streams.video.elementary.checksum = checksum(esinfo.video);
          }
        }
      };
      return info;
    });
    playlistsJournal[stream] = segmentsInfo;
  });
  return playlistsJournal;
}

module.exports = {
  metadata: metadata,
  extractElementaryStreams: extractElementaryStreams,
  checksum: checksum,
  create: create,
}
