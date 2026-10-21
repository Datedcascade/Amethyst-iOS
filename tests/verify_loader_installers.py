"""Inspect official installers and reproduce BTA's classloader boundary on desktop."""
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import urllib.request
import zipfile

root=Path(__file__).resolve().parents[1]
work=Path(os.environ['RUNNER_TEMP'])/'amethyst-loader-checks'
work.mkdir(exist_ok=True)
def download(url):
    request=urllib.request.Request(url,headers={'User-Agent':'Amethyst-Personal-Build'})
    with urllib.request.urlopen(request,timeout=120) as response:return response.read()
urls=[
'https://maven.minecraftforge.net/net/minecraftforge/forge/1.12.2-14.23.5.2860/forge-1.12.2-14.23.5.2860-installer.jar',
'https://maven.minecraftforge.net/net/minecraftforge/forge/1.20.1-47.4.0/forge-1.20.1-47.4.0-installer.jar',
'https://maven.neoforged.net/releases/net/neoforged/neoforge/21.1.200/neoforge-21.1.200-installer.jar']
for index,url in enumerate(urls):
    data=download(url)
    assert hashlib.sha1(data).hexdigest()==download(url+'.sha1').decode().strip()[:40].lower()
    jar=work/f'installer-{index}.jar';jar.write_bytes(data)
    subprocess.run(['java','-cp',os.environ.get('AMETHYST_TEST_LAUNCHER',str(root/'JavaApp/build/launcher.jar'))+os.pathsep+str(jar),
                    'net.kdt.pojavlaunch.ModpackLoaderInstaller','--inspect-installer',str(jar)],check=True)

folder=work/'bta';folder.mkdir(exist_ok=True)
package=download('https://downloads.betterthanadventure.net/bta-client/release/v8.0.1/bta.v8.0.1.mmc.zip')
assert hashlib.sha256(package).hexdigest()=='22fca951e22f9572e2e23437ce828bb67424f773eb913082e2e36aa917764236'
with zipfile.ZipFile(io.BytesIO(package)) as archive:(folder/'bta.jar').write_bytes(archive.read('jarmods/bta.jar'))
metadata=json.loads((root/'Natives/resources/bta/bta-8.0.1.json').read_text())
for index,library in enumerate(metadata['libraries']):
    artifact=library.get('downloads',{}).get('artifact')
    if not artifact:continue
    data=download(artifact['url']);assert hashlib.sha1(data).hexdigest()==artifact['sha1']
    name='bridge.jar' if ':legacy-lwjgl3:' in library['name'] else f'library-{index}.jar'
    (folder/name).write_bytes(data)
subprocess.run(['javac','-d',str(work),str(root/'tests/BTAClassVisibilityTests.java')],check=True)
subprocess.run(['java','-cp',str(work),'BTAClassVisibilityTests',str(folder),os.environ.get('AMETHYST_TEST_LWJGL',str(root/'JavaApp/build/lwjgl-3.3.3.jar'))],check=True,cwd=root)

# Exercise a real modern Forge processor chain in an isolated directory.
fixture=work/'forge-client';fixture.mkdir(exist_ok=True)
manifest=json.loads(download('https://piston-meta.mojang.com/mc/game/version_manifest_v2.json'))
entry=next(item for item in manifest['versions'] if item['id']=='1.20.1')
data=download(entry['url']);assert hashlib.sha1(data).hexdigest()==entry['sha1']
version=json.loads(data);client=version['downloads']['client']
directory=fixture/'versions/1.20.1';directory.mkdir(parents=True,exist_ok=True)
(directory/'1.20.1.json').write_bytes(data)
data=download(client['url']);assert hashlib.sha1(data).hexdigest()==client['sha1']
(directory/'1.20.1.jar').write_bytes(data)
(fixture/'launcher_profiles.json').write_text('{"profiles":{}}')
subprocess.run(['javac','-d',str(work),str(root/'tests/ForgeClientInstallSmokeTest.java')],check=True)
classpath=os.pathsep.join([str(work),os.environ.get('AMETHYST_TEST_LAUNCHER',str(root/'JavaApp/build/launcher.jar')),str(work/'installer-1.jar')])
with (work/'forge-client-install.log').open('w') as log:
    result=subprocess.run(['java','-cp',classpath,'ForgeClientInstallSmokeTest',str(work/'installer-1.jar'),str(fixture)],stdout=log,stderr=subprocess.STDOUT,timeout=300)
if result.returncode:
    print('\n'.join((work/'forge-client-install.log').read_text().splitlines()[-40:]))
    raise SystemExit(result.returncode)
print('Full official Forge client installation and processor outputs passed.')

