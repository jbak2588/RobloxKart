"""Extract inert exterior-only city palette; never edits the source place."""
from pathlib import Path
import copy
import hashlib
import math
import xml.etree.ElementTree as ET

SOURCE = Path('C:/dev/rbxlx_data/city.rbxlx')
TARGET = Path('src/assets/KDMMetroResources.rbxmx')
PART_PROPS = {'Name', 'CFrame', 'size', 'Size', 'Color3uint8', 'Color', 'Material',
              'MaterialVariantSerialized', 'MeshId', 'TextureID', 'Transparency',
              'Reflectance', 'DoubleSided', 'RenderFidelity', 'shape'}
IMAGE_PROPS = {'Name', 'AlphaMode', 'Color', 'ColorMap', 'MetalnessMap', 'NormalMap',
               'RoughnessMap', 'Texture', 'Color3', 'Transparency', 'Face',
               'StudsPerTileU', 'StudsPerTileV', 'OffsetStudsU', 'OffsetStudsV'}

def name(item):
    return item.findtext("Properties/string[@name='Name']")

def named(parent, child):
    return next(i for i in parent.findall('Item') if name(i) == child)

def vector(p, prop):
    v = p.find(f"Vector3[@name='{prop}']")
    return [float(v.findtext(k)) for k in ['X', 'Y', 'Z']]

def frame(p):
    c = p.find("CoordinateFrame[@name='CFrame']")
    return [float(c.findtext(k)) for k in ['X', 'Y', 'Z']], [
        [float(c.findtext(f'R{i}{j}')) for j in range(3)] for i in range(3)]

def inert_part(item, origin, front, index):
    node = ET.Element('Item', {'class': item.get('class'), 'referent': f'Metro{index}'})
    props = ET.SubElement(node, 'Properties')
    original = item.find('Properties')
    for p in original:
        if p.get('name') in PART_PROPS:
            props.append(copy.deepcopy(p))
    mesh = original.findtext("Content[@name='MeshId']/url")
    # Unique, stable names also retain the immutable mesh identity for authoring repair.
    props.find("string[@name='Name']").text = (
        f'Mesh_{mesh.split("//")[-1]}_{index:04d}' if mesh else f'Part_{index:04d}')
    for k, value in {'Anchored': True, 'CanCollide': False, 'CanTouch': False,
                     'CanQuery': False, 'CastShadow': False}.items():
        ET.SubElement(props, 'bool', {'name': k}).text = str(value).lower()
    pos, rot = frame(original)
    fx, fz = front
    basis = [[-fz, 0, fx], [0, 1, 0], [-fx, 0, -fz]]
    delta = [pos[i] - origin[i] for i in range(3)]
    lp = [sum(basis[i][j] * delta[j] for j in range(3)) for i in range(3)]
    lr = [[sum(basis[i][k] * rot[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    cf = props.find("CoordinateFrame[@name='CFrame']")
    for k, v in zip(['X', 'Y', 'Z'], lp):
        cf.find(k).text = f'{v:.9f}'
    for i in range(3):
        for j in range(3):
            cf.find(f'R{i}{j}').text = f'{lr[i][j]:.9f}'
    for image in item.findall('Item'):
        if image.get('class') not in ('SurfaceAppearance', 'Texture', 'Decal'):
            continue
        im = ET.SubElement(node, 'Item', {'class': image.get('class'), 'referent': f'MetroImage{index}_{len(node)}'})
        ip = ET.SubElement(im, 'Properties')
        for p in image.find('Properties'):
            if p.get('name') in IMAGE_PROPS:
                ip.append(copy.deepcopy(p))
    return node

def bounds(parts):
    low,high=[math.inf]*3,[-math.inf]*3
    for item in parts:
        p=item.find('Properties');pos,rot=frame(p);size=vector(p,'size')
        ext=[sum(abs(rot[i][j])*size[j]/2 for j in range(3)) for i in range(3)]
        for i in range(3):low[i]=min(low[i],pos[i]-ext[i]);high[i]=max(high[i],pos[i]+ext[i])
    return low,high

def main():
    source=ET.parse(SOURCE).getroot();workspace=named(source,'Workspace')
    city=named(workspace,'City_Template');streets=named(city,'Streets_Sidewalks')
    originals=named(named(workspace,'Endorsed Models'),'PrefabBuildings')
    out=ET.Element('roblox',{'version':'4'})
    root=ET.SubElement(out,'Item',{'class':'Folder','referent':'MetroResources'})
    rp=ET.SubElement(root,'Properties');ET.SubElement(rp,'string',{'name':'Name'}).text='KDMMetroResources'
    candidates=[];names={}
    for original in originals.findall('Item'):
        key='Kit_'+name(original);names[key]=names.get(key,0)+1
        if names[key]>1:key+='_'+str(names[key])
        parts=[p for g in original.findall('Item') if name(g)!='Set_Dressing'
               for p in g.iter('Item') if p.get('class') in ('Part','MeshPart','WedgePart')]
        candidates.append((key,parts,'Building'))
    buildings=named(city,'CityTemplateBuildings')
    for i,bridge in enumerate([m for m in buildings.findall('Item') if name(m)=='Skybridge'],1):
        candidates.append(('Skybridge'+str(i),[p for p in bridge.iter('Item') if p.get('class') in ('Part','MeshPart','WedgePart')],'Bridge'))
    lamps=next(n for n in city.iter('Item') if name(n)=='StreetLights')
    lamp=next(n for n in lamps.findall('Item') if name(n)=='StreetLamp_A')
    candidates.append(('StreetLamp_A',[p for p in lamp.iter('Item') if p.get('class') in ('Part','MeshPart')],'Lamp'))
    count=0
    for key,parts,kind in candidates:
        low,high=bounds(parts);center=[(low[i]+high[i])/2 for i in range(3)]
        model=ET.SubElement(root,'Item',{'class':'Model','referent':'Metro'+key})
        mp=ET.SubElement(model,'Properties');ET.SubElement(mp,'string',{'name':'Name'}).text=key
        front_count=0
        for item in parts:
            count+=1;part=inert_part(item,[center[0],low[1],center[2]],(0,-1),count)
            pp=part.find('Properties');pos,rot=frame(pp);size=vector(pp,'size')
            ext=[sum(abs(rot[i][j])*size[j]/2 for j in range(3)) for i in range(3)]
            face='Solid'
            if kind=='Building' and item.get('class')=='MeshPart':
                # Native complete shells remain in the palette. Only hidden shared
                # decoration is culled per block at runtime; no fabricated facades.
                if pos[2]+ext[2] < -(high[2]-low[2])*.18:face='Front'
                elif pos[2]-ext[2] > (high[2]-low[2])*.18:face='Rear'
                elif abs(pos[0])>(high[0]-low[0])*.22:face='Side'
                else:face='Structure'
            if face=='Front':front_count+=1
            pp.find("string[@name='Name']").text+='_'+face
            model.append(part)
        print(key,len(parts),'front',front_count,'size',[round(high[i]-low[i],1) for i in range(3)])
    # Only source atmosphere/sky and a small, bounded material palette.
    for service_name, folder_name, classes in [
        ('Lighting', 'Lighting', {'Sky', 'Atmosphere', 'ColorCorrectionEffect'}),
        ('MaterialService', 'Materials', {'MaterialVariant'}),
    ]:
        folder = ET.SubElement(root, 'Item', {'class': 'Folder', 'referent': 'Metro' + folder_name})
        fp = ET.SubElement(folder, 'Properties'); ET.SubElement(fp, 'string', {'name': 'Name'}).text = folder_name
        for item in named(source, service_name).findall('Item'):
            if item.get('class') in classes:
                clean = copy.deepcopy(item)
                props = clean.find('Properties')
                for prop in list(props):
                    if prop.tag in ('SharedString', 'UniqueId', 'BinaryString', 'SecurityCapabilities') or prop.get('name') in {'SourceAssetId','DefinesCapabilities','TexturePack','EmissiveMaskContent'}:
                        props.remove(prop)
                folder.append(clean)
        if folder_name == 'Materials':
            desert=ET.parse('src/assets/KDMDesertResources.rbxmx').getroot()
            matte=copy.deepcopy(next(n for n in desert.iter('Item') if name(n)=='Racing_Asphalt_A'))
            matte.set('referent','MetroMatteAsphalt')
            props=matte.find('Properties')
            for prop in list(props):
                if prop.tag in ('SharedString','UniqueId','BinaryString','SecurityCapabilities') or prop.get('name') in {'SourceAssetId','DefinesCapabilities','TexturePack','EmissiveMaskContent'}:
                    props.remove(prop)
            props.find("string[@name='Name']").text='Metro_Racing_Asphalt_Matte'
            normal=props.find("Content[@name='NormalMap']")
            normal.clear();normal.set('name','NormalMap');ET.SubElement(normal,'null')
            folder.append(matte)
    ET.indent(out)
    TARGET.write_bytes(ET.tostring(out, encoding='utf-8'))
    print('parts', count, 'bytes', TARGET.stat().st_size)
    print('source SHA256', hashlib.sha256(SOURCE.read_bytes()).hexdigest())

if __name__ == '__main__':
    main()
