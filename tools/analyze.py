import glob, os, platform, subprocess, sys
import hashlib
import json
import re
from pprint import pprint

from deepdiff import DeepDiff

VER = '1.11.4'
DIR = os.path.abspath(os.path.dirname(__file__))

# cross detection
OSTYPE = sys.platform

def get_command_output(command):
    p = subprocess.Popen(
      command,
      stdout=subprocess.PIPE,
      stderr=subprocess.PIPE,
      stdin=subprocess.PIPE
    )
    return p.communicate()

def get_server_root(server):
    return os.path.join(DIR, "%s-%s-%s" % (VER, OSTYPE, server))

def get_segments_root(server):
    SERVER_ROOT = get_server_root(server)
    return os.path.join(SERVER_ROOT, 'temp', 'hls_temp')

def get_segment_mediainfo(segment_path):
    extinfo  = os.path.splitext(segment_path)
    filename = os.path.basename(extinfo[0])
    extension = extinfo[1]
    checksum = hashlib.sha256(open(segment_path, 'rb').read()).hexdigest()
    streams = {
        'audio': None,
        'video': None,
    }
    out, err = get_command_output([
        'ffprobe',
        '-v', 'quiet',
        '-print_format', 'json',
        '-show_format',
        '-show_streams',
        segment_path
    ])
    info = json.loads(out)
    del info['format']['filename']
    mediainfo = {
        #'path': os.path.abspath(segment_path),
        'file': {
            'checksum': checksum,
            'name': filename,
            'extension': extension,
        },
        'format': info['format'],
    } 
    return mediainfo

def get_segments_journal(server, stream):
    files = glob.glob(os.path.join(get_segments_root(server), '*.ts'))
    files.sort(key=lambda var:[int(x) if x.isdigit() else x for x in re.findall(r'[^0-9]|[0-9]+', var)])
    segments = {}
    for file in files:
        mediainfo = get_segment_mediainfo(file)
        segments[mediainfo['file']['name']] = mediainfo 
    return segments

def get_segments_journal_cached(server, stream):
  journal_path = os.path.join(DIR, 'journal.%s' % server)
  if os.path.exists(journal_path):
      journal = json.loads(open(journal_path).read())
  else:
      journal = get_segments_journal(server, stream)
      with open(journal_path, 'w') as f:
          f.write(json.dumps(journal))
          f.close()
  return journal

def get_journal_diff(journal_l, journal_r):
    diff = {
        'missing': [],
        'checksum': {},
        'start_time': {},
        'bit_rate': {},
        'duration': {},
        'size': {},
    }
    for key in journal_l:
        info_l = journal_l[key]
        if key not in journal_r:
            diff['missing'].append(key)
            continue
        info_r = journal_r[key]
        # Test checksums
        # print '%s vs %s' % (info_l['file']['checksum'], info_r['file']['checksum'])
        if info_l['file']['checksum'] != info_r['file']['checksum']:
            diff['checksum'][key] = { 'expected': info_l['file']['checksum'], 'received': info_r['file']['checksum'] }
        # format check
        m_l = info_l['format']
        m_r = info_r['format']
        # Format info check even if different checksum
        if m_l['start_time'] != m_r['start_time']:
            diff['start_time'][key] = [m_l['start_time'], m_r['start_time']]
        if m_l['bit_rate'] != m_r['bit_rate']:
            diff['bit_rate'][key] = [m_l['bit_rate'], m_r['bit_rate']]
        if m_l['duration'] != m_r['duration']:
            diff['duration'][key] = [m_l['duration'], m_r['duration']]
        if m_l['size'] != m_r['size']:
            diff['size'][key] = [m_l['size'], m_r['size']]

    return diff;

STREAM ='s1'
journal_o = get_segments_journal_cached('origin', STREAM)
journal_e = get_segments_journal_cached('edge', STREAM)

delta = get_journal_diff(journal_o, journal_e)
pprint(delta)
sys.exit(0);

segments_edge_root = get_segments_root('edge')
segments_delta = {
    'missing': [],
    'different': []
}
for seg_key in segments_origin:
    segment_origin = segments_origin[seg_key]
    if seg_key not in segments_edge:
        segments_delta['missing'].append(segment_origin)
        continue
    # actual compare
    segment_edge = os.path.join(segments_edge_root, segment_origin['filename'] + segment_origin['extension'])
    if not os.path.exists(segment_edge):
        segments_delta['missing'].append(segment_origin)
        continue

pprint(segments_delta)
