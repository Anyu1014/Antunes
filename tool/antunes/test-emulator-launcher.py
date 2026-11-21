from pathlib import Path
import os,subprocess,sys,tempfile
source=Path(sys.argv[1]);expected=sys.argv[2] if len(sys.argv)>2 else 'host'
cache=Path(__file__).resolve().parents[3]/'.cache'
with tempfile.TemporaryDirectory(dir=cache) as temp:
    root=Path(temp);record=root/'args';stub=root/'emulator';stub.write_text('#!/bin/bash\nprintf "%s\\n" "$@" > "$ARG_FILE"\n');stub.chmod(0o755)
    test=root/'launcher.sh';text=source.read_text();entry='/Users/y/toolchains/bin/emulator';assert entry in text
    test.write_text(text.replace(entry,'"'+str(stub)+'"'))
    subprocess.run(['/bin/bash',str(test)],env={**os.environ,'ARG_FILE':str(record)},check=True)
    args=record.read_text().splitlines();actual=args[args.index('-gpu')+1] if '-gpu' in args else 'auto'
    ok=actual==expected and '-wipe-data' not in args and args[args.index('-avd')+1]=='dev'
    print(f'LAUNCHER: gpu={actual}; expected={expected}; wipe-data=absent; {"PASS" if ok else "FAIL"}')
    sys.exit(0 if ok else 1)
