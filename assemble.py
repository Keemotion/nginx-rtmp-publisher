import argparse, glob, os, platform, re, subprocess, sys
from pprint import pprint

VER = '1.11.4'
DIR = os.path.dirname(__file__)
TMP = os.path.join(DIR, 'tmp')

def list_sorted_files(pattern):
    print pattern
    files = glob.glob(pattern)
    files.sort(key=lambda var:[
      int(x) if x.isdigit() else x for x in re.findall(r'[^0-9]|[0-9]+', var)
    ])
    return files

def assemble(stream, root, server='origin', version=VER):
    base = '%s%s' % (root, stream)
    index = os.path.join(root, '%s-0-segments.txt' % stream)
    files = list_sorted_files(os.path.join(root, stream) + '*.ts')
    # create temporary index file for ffmpeg assembler if it does not exist
    if not os.path.exists(index):
      with open(index, 'w') as f:
          for file in files:
              segment = os.path.basename(file)
              f.write("file '%s'\n" % segment)
          f.close()
    # execute assemble if index files exist
    if not os.path.exists(index):
        print('No index in expected location `%s`' % index)
        sys.exit(1)
    # build the command
    cmd = [
        'ffmpeg',
        '-y', 
        '-f', 'concat', 
        '-i', index,
        '-c:a', 'copy',
        '-c:v', 'copy',
        '-bsf:a', 'aac_adtstoasc',
        '-shortest',
        '-avoid_negative_ts',
        'make_zero',
        '-fflags', '+genpts',
        os.path.join(TMP, '%s-%s-%s.mp4' % (sys.platform, server, stream))
    ]
    print 'Assembling with:\n%s' % (' '.join(cmd),)
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE)
    status, error = p.communicate()
    if status <> 0:
        print('Could not finish properly: \n%s' % error)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(prog=os.path.basename(__file__), usage='%(prog)s [options]')
    parser.add_argument(
        '--version',
        help='The version of nginx',
        default=VER
    )
    parser.add_argument(
        '--server',
        help='Either origin or edge',
        default='origin'
    )
    parser.add_argument(
        '--stream', 
        help='The prefix name of the stream to be assembled inside the server hls_temp',
        default='bipbop-gear3'
    )
    args = parser.parse_args()
    root = '%s-%s-%s' % (args.version, sys.platform, args.server)
    assemble(
      stream=args.stream,
      root=os.path.join(DIR, 'builds', root, 'temp', 'hls_temp'),
      server=args.server,
      version=args.version,
    )
