import argparse, glob, json, os, platform, re, subprocess, sys, tempfile
from pprint import pprint

DIR = os.path.dirname(__file__)
TMP = os.path.join(DIR, 'tmp')

def execute_command(command):
    #print(' '.join(command))
    p = subprocess.Popen(
      command,
      stdout=subprocess.PIPE,
      stderr=subprocess.PIPE,
      stdin=subprocess.PIPE
    )
    stdout, stderr = p.communicate()
    if p.returncode <> 0:
        print('Could not finish properly: \n%s' % (stdout + '\n' + stderr))
        sys.exit(p.returncode)
    return stdout

def list_sorted_files(pattern):
    files = glob.glob(pattern)
    files.sort(key=lambda var:[
      int(x) if x.isdigit() else x for x in re.findall(r'[^0-9]|[0-9]+', var)
    ])
    return files

def checksum_for_file(input):
    cmd = [
      'sha1sum',
      input
    ]
    output = execute_command(cmd)
    return output.split(' ')[0]

def checksums_for_segment(input):
    retval = {
      'audio': None,
      'video': None,
    }
    # extract elementary streams to temp file
    if not os.path.exists(input):
        return retval
    with tempfile.NamedTemporaryFile(prefix='segment-' + os.path.basename(input)) as tmpfile:
        # - audio
        cmd_audio = [
          'ffmpeg',
          '-y', 
          '-i', input,
          '-c:a', 'copy',
          '-c:v', 'none',
          '-f', 'ac3',
          tmpfile.name + '.ac3'
        ]
        execute_command(cmd_audio)
        # - video
        cmd_video = [
          'ffmpeg',
          '-y', 
          '-i', input,
          '-c:a', 'none',
          '-c:v', 'copy',
          '-f', 'h264',
          tmpfile.name + '.h264'
        ]
        execute_command(cmd_video)
        # - checksum over generated audio and video streams
        retval['audio'] = checksum_for_file(tmpfile.name + '.ac3')
        retval['video'] = checksum_for_file(tmpfile.name + '.h264')
    return retval

if __name__ == '__main__':
    parser = argparse.ArgumentParser(prog=os.path.basename(__file__), usage='%(prog)s [options]')
    parser.add_argument(
        '--input',
        help='The directory where mpeg-ts segments are stored',
        required=True
    )
    parser.add_argument(
        '--journal',
        help='The directory where mpeg-ts segments are stored',
        required=False
    )
    args = parser.parse_args()
    # journal
    journal_path = os.path.join(args.input, 'journal.json')
    if args.journal:
        journal_path = args.journal
    # platform detection
    platform = sys.platform
    if sys.platform.lower() in ['win32', 'win64']:
        # windows
        msystem = os.environ.get('MSYSTEM')
        if msystem is not None and msystem.lower() in ['mingw32', 'mingw64']:
            platform = 'msys'
        else:
            platform = 'win'
    inputdir = os.path.abspath(args.input)
    segments = list_sorted_files(os.path.join(inputdir, '*.ts'))
    # journal means file name as key and file size as checksum
    withChecksum = False
    journal = {}
    for index, segment in enumerate(segments):
        key = os.path.splitext(os.path.basename(segment))[0]
        size = os.stat(segment).st_size
        report = {
          'index': index,
          'size': size,
        }
        if withChecksum:
            report['checksum'] = checksums_for_segment(segment) 
        journal[key] = report
    # write journal
    with open(journal_path, 'w') as f:
        f.write(json.dumps(journal, sort_keys=True, indent=2, separators=(',', ': ')))
        f.close()
 