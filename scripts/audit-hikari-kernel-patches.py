#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
from pathlib import Path
import subprocess, os, tempfile, json
import argparse
parser=argparse.ArgumentParser(description='Test omission of every commit in a materialized kernel stack')
parser.add_argument('kernel_tree')
parser.add_argument('--output-prefix', required=True)
args=parser.parse_args()
repo=Path(__file__).resolve().parent.parent
src=str(Path(args.kernel_tree).resolve())
base=next(line.split('=',1)[1] for line in (repo/'kernel/source.lock').read_text().splitlines() if line.startswith('LINUX_BASE='))
def git(*a,**kw): return subprocess.check_output(['git','-C',src,*a],**kw)
git('merge-base','--is-ancestor',base,'HEAD')
commits=git('rev-list','--reverse',base+'..HEAD').decode().splitlines()
if not 1 <= len(commits) <= 512:
 raise SystemExit('Expected a materialized Hikari patch stack of 1..512 commits')
paths=git('diff','--name-only',base,'HEAD').decode().splitlines()
# Include files later reverted too, so every intermediate patch is represented.
paths=sorted(set(paths)|set(git('log','--format=','--name-only',base+'..HEAD').decode().splitlines())-{''})
entries=git('ls-tree','-r',base,'--',*paths).decode()
index_entries=''.join(line.replace('\t','\t',1) for line in entries.splitlines(True))
diffs=[git('diff-tree','--no-commit-id','--binary','--full-index','-p',c) for c in commits]
subjects=[git('show','-s','--format=%s',c).decode().strip() for c in commits]
with tempfile.TemporaryDirectory(prefix='hikari-audit-') as d:
 env=dict(os.environ,GIT_INDEX_FILE=d+'/index')
 def run(skip):
  subprocess.run(['git','-C',src,'read-tree','--empty'],env=env,check=True)
  subprocess.run(['git','-C',src,'update-index','--index-info'],input=index_entries.encode(),env=env,check=True)
  for i,diff in enumerate(diffs):
   if i in skip: continue
   r=subprocess.run(['git','-C',src,'apply','--cached','--whitespace=nowarn','-'],input=diff,env=env,stderr=subprocess.PIPE)
   if r.returncode: return None,subjects[i]
  return git('write-tree',env=env).decode().strip(),''
 expected,error=run(set()); assert expected,error
 rows=[]; noop=[]
 for i,c in enumerate(commits):
  tree,error=run({i})
  status='DEPENDENCY' if tree is None else 'NO_FINAL_EFFECT' if tree==expected else 'CHANGES_FINAL_TREE'
  if status=='NO_FINAL_EFFECT': noop.append(i)
  rows.append((c,subjects[i],status,error))
 combined,_=run(set(noop))
 out=Path(args.output_prefix+'.tsv')
 out.parent.mkdir(parents=True,exist_ok=True)
 out.write_text('commit\tsubject\tclassification\tdependent_patch\n'+''.join('\t'.join(value or '-' for value in r)+'\n' for r in rows))
 Path(args.output_prefix+'.json').write_text(json.dumps({'baseline_subset_tree':expected,'no_effect_commits':[commits[i] for i in noop],'combined_removal_same_tree':combined==expected},indent=2)+'\n')
 print('Audited',len(commits),'commits; no-effect commits:',len(noop),'combined equivalence:',combined==expected)
 for i in noop: print(commits[i],subjects[i])
