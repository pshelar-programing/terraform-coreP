import groovy.json.JsonSlurper

////def jsonSlurper = new JsonSlurper()
////def config = jsonSlurper.parse(new File('config.json'))

//def config = getConfig()
//def retFunc = getEnvConfig(config)

//println "configRet = $retFunc"

//def retFuncAc = getActionConfig(config)
//println "configRet = $retFuncAc"

def getEnvConfig(def config) {
    println "config.environment = ${config.environment}"
    String str = config.environment
    return str
}

def getActionConfig(def config) {
    println "config.action = ${config.action}"
    String str = config.action
    return str
}

def getConfig(){
    def jsonSlurper = new JsonSlurper()
    def config = jsonSlurper.parse(new File('config.json'))
    println "config = $config"
    return config
}

return config

