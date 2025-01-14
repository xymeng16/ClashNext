import { Profile, ProfileRepo, ProfileType } from './ProfileRepo'
import { common } from '@kit.AbilityKit'
import fs from '@ohos.file.fs'
import { nativeFetchAndValid, nativeInit, nativeInstallSideloadGeoip } from 'libentry.so'
import { promptAction } from '@kit.ArkUI'

export class ProfileViewModel{
  repo:ProfileRepo = new ProfileRepo()
  context: common.Context | undefined
  async init(context:common.Context){
    this.context = context
    await this.repo.init(context)
    // await nativeInit(await this.getHome(),"")
  }
  async  getProfileList(): Promise<Profile[]>{
    return await this.repo.queryAll()
  }
  async  getActive(): Promise<Profile | undefined>{
    let profile =  await this.repo.queryAll()
    return profile.find((p) => p.active)
  }
  async getProfile(uuid: string | undefined): Promise<Profile>{
    try {
      let profile =  await this.repo.query(uuid)
      if (profile)
        return profile
    }catch (e){
      console.error("Clash", e, e.stack)
    }
    return new Profile();
  }

  private async saveProfile(profile: Profile){
    await this.repo.addOrUpdate(profile)
  }



  async updateProfile(profile:Profile){
    await this.repo.addOrUpdate(profile)
  }

  async  activeProfile(profile: Profile){
    profile.active = true
    const list = await this.getProfileList()
    for (let d of list){
      if(d.uuid != profile.uuid){
        d.active = false
        await this.saveProfile(d)
      }
      else{
        d.active = true
        await this.saveProfile(d)
      }
    }
  }
  async delete(uuid: string){
    await this.repo.delete(uuid)
  }
  async addProfile(profile:Profile): Promise<boolean>{
    const configPath = await this.getConfigPath(profile)
    if(profile.type == ProfileType.Url) {
      const result = await this.download(configPath, profile.source)
      if(result){
        await this.saveProfile(profile)
        return true
      }else{
        promptAction.showToast({message:"下载配置文件失败"})
        return false
      }
    }else{
    }
    return false
  }

  async download(configPath:string, url: string): Promise<boolean>{
    return new Promise((resolve, reject)=>{
      nativeFetchAndValid(configPath, url, false, (type:string, value:string)=>{
        console.debug("nativeFetchAndValid ", type)
        if (type == "fetch_complete"){
            if(fs.accessSync(configPath + "/config.yaml")){
              resolve(true)
            }else{
              resolve(false)
            }
        }
      })
    })

  }
  async getConfigPath(profile: Profile): Promise<string>{
    const imported = this.context?.filesDir +"/import/"
    if(!await fs.access(imported, fs.AccessModeType.EXIST)){
       await fs.mkdir(imported)
    }
    const configPath = imported + profile.uuid
    if(!await fs.access(configPath, fs.AccessModeType.EXIST)){
      await fs.mkdir(configPath)
    }
    return configPath
  }

  async getActiveConfigPath(): Promise<string | undefined>{
    const profile = await this.getActive()
    if (!profile)
      return undefined
    return this.getConfigPath(profile)
  }
  async getHome():Promise<string>{
    const home = this.context?.filesDir +"/home/"
    if (!await fs.access(home, fs.AccessModeType.EXIST)){
      await fs.mkdir(home)
    }
    return home;
  }
  async initGeoIp(){
    let geoIp = await readFile(this.context?.resourceDir + "/geoip.metadb")
    writeFile(await this.getHome() + "geoip.metadb", geoIp)
    let geoSite = await readFile(this.context?.resourceDir + "/geosite.dat")
    writeFile(await this.getHome() + "geosite.dat", geoSite)
    // if(bytes != null){
    //   nativeInstallSideloadGeoip(bytes)
    // }
  }
}
export async  function readFile(filePath: string): Promise<Uint8Array | null> {
  if(!await fs.access(filePath))
    return null;
  const file = await fs.open(filePath)
  const stats = await fs.stat(filePath)
  let bufSize = stats.size;
  let buf = new ArrayBuffer(bufSize);
  await fs.read(file.fd, buf, { offset: 0, length: bufSize });
  await fs.close(file);
  return new Uint8Array(buf);
}
export function writeFile(filePath: string, data: Uint8Array | null) {
  if(data != null && data.byteLength > 0){
    const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE)
    fs.writeSync(file.fd, data.buffer);
    fs.fsyncSync(file.fd)
    fs.closeSync(file);
  }
}
export default new ProfileViewModel()