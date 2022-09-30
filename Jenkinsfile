pipeline {
  agent {
    kubernetes {
      cloud 'kubernetes'
      slaveConnectTimeout 1200
      workspaceVolume hostPathWorkspaceVolume(hostPath: "/opt/workspace", readOnly: false)
      yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:                                                         #整个cicd流程所需要的工作环境，agent.pod! 每个容器都有各自的功能，编译的、做镜像的、部署的等等
    - args: [\'$(JENKINS_SECRET)\', \'$(JENKINS_NAME)\']
      image: 'registry.cn-beijing.aliyuncs.com/citools/jnlp:alpine'
      name: jnlp                                                      #jnlp是Jenkins slave与master通信的！
      imagePullPolicy: IfNotPresent
      volumeMounts:
        - mountPath: "/etc/localtime"
          name: "localtime"
          readOnly: false
    - command:
        - "cat"
      env:
        - name: "LANGUAGE"
          value: "en_US:en"
        - name: "LC_ALL"
          value: "en_US.UTF-8"
        - name: "LANG"
          value: "en_US.UTF-8"
      image: "registry.cn-beijing.aliyuncs.com/citools/maven:3.5.3"
      imagePullPolicy: "IfNotPresent"
      name: "build"
      tty: true
      volumeMounts:
        - mountPath: "/etc/localtime"
          name: "localtime"
        - mountPath: "/root/.m2/"
          name: "cachedir"
          readOnly: false
    - command:
        - "cat"
      env:
        - name: "LANGUAGE"
          value: "en_US:en"
        - name: "LC_ALL"
          value: "en_US.UTF-8"
        - name: "LANG"
          value: "en_US.UTF-8"
      image: "registry.cn-beijing.aliyuncs.com/citools/kubectl:self-1.17"
      imagePullPolicy: "IfNotPresent"
      name: "kubectl"
      tty: true
      volumeMounts:
        - mountPath: "/etc/localtime"
          name: "localtime"
          readOnly: false
    - command:
        - "cat"
      env:
        - name: "LANGUAGE"
          value: "en_US:en"
        - name: "LC_ALL"
          value: "en_US.UTF-8"
        - name: "LANG"
          value: "en_US.UTF-8"
      image: "registry.cn-beijing.aliyuncs.com/citools/docker:19.03.9-git"
      imagePullPolicy: "IfNotPresent"
      name: "docker"
      tty: true
      volumeMounts:
        - mountPath: "/etc/localtime"
          name: "localtime"
          readOnly: false
        - mountPath: "/var/run/docker.sock"         #docker命令执行的时候必须要有docker.sock在，所以我们在宿主机上装docker，让pod.docker去用宿主机docker服务的sock。
          name: "dockersock"
          readOnly: false
  restartPolicy: "Never"
  nodeSelector:
    build: "true"
  securityContext: {}
  volumes:
    - hostPath:
        path: "/var/run/docker.sock"
      name: "dockersock"
    - hostPath:
        path: "/usr/share/zoneinfo/Asia/Shanghai"
      name: "localtime"
    - name: "cachedir"
      hostPath:
        path: "/opt/m2"
'''
    }

//上面就是k8s.agent使用，也可以当模板给其他流水线使用

}
  stages {
    stage('Pulling Code') {
      parallel {    //并发
        stage('Pulling Code by Jenkins') {
          when {
            expression {
              env.gitlabBranch == null     //如果gitlabBranch是空值，才会执行下面的steps!   因为从Jenkins web页面点击的构建gitlabBranch就是null！！！
            }                              // gitlabBranch 可以区分是Jenkins web上点的构建 还是 gitlab触发的构建！ 

          }
          steps {
            git(changelog: true, poll: true, url: 'git@10.201.83.238:kubernetes/spring-boot-project.git', branch: "${BRANCH}", credentialsId: 'gitlab-key')
            script {
              COMMIT_ID = sh(returnStdout: true, script: "git log -n 1 --pretty=format:'%h'").trim()
              TAG = BUILD_TAG + '-' + COMMIT_ID
              println "Current branch is ${BRANCH}, Commit ID is ${COMMIT_ID}, Image TAG is ${TAG}"

            }

          }
        }

        stage('Pulling Code by trigger') {
          when {
            expression {
              env.gitlabBranch != null   //如果gitlabBranch 不是空值，才会执行下面的steps!  //gitlab触发的构建gitlabBranch就不为空！！！
            }

          }
          steps {
            git(url: 'git@10.201.83.238:kubernetes/spring-boot-project.git', branch: env.gitlabBranch, changelog: true, poll: true, credentialsId: 'gitlab-key')
            script {
              COMMIT_ID = sh(returnStdout: true, script: "git log -n 1 --pretty=format:'%h'").trim()   // returnStdout: true  标准输出 // git log -n 1 --pretty=format:'%h'  这个命令能拿到git的 commit id
              TAG = BUILD_TAG + '-' + COMMIT_ID         // TAG = Jenkins.静态变量BUILD_TAG-上面拿到的COMMIT_ID ！！！
              println "Current branch is ${env.gitlabBranch}, Commit ID is ${COMMIT_ID}, Image TAG is ${TAG}"
            }    // returnStdout: true  标准输出     // git log -n 1 --pretty=format:'%h'  这个命令能拿到git的 commit id    // BUILD_TAG 是Jenkins 的一个静态变量！

          }
        }

      }
    }

    stage('Building') {
      steps {
        container(name: 'build') {                //在k8s.agent pod 中的 build 容器里执行下面的sh命令.
            sh """
              mvn clean install -DskipTests       #编译命令和开发人员确定
            """
        }
      }
    }

    stage('Docker build for creating image') {
      environment {
        HARBOR_USER     = credentials('harbor-admin')             //harbor仓库的用户密码做到了Jenkins的全局凭证里,这是其凭证的id
    }
      steps {
        container(name: 'docker') {
          sh """
          echo ${HARBOR_USER_USR} ${HARBOR_USER_PSW} ${TAG}                           #镜像的名称 和 容器名称 和deploy(pod控制器)的label,是一致的        #dukuan cicd 经验
          docker build -t ${HARBOR_ADDRESS}/${REGISTRY_DIR}/${IMAGE_NAME}:${TAG} .    #变量${TAG}是全局变量，在Pulling Code环节修改了其(TAG)的值!
          docker login -u ${HARBOR_USER_USR} -p ${HARBOR_USER_PSW} ${HARBOR_ADDRESS}
          docker push ${HARBOR_ADDRESS}/${REGISTRY_DIR}/${IMAGE_NAME}:${TAG}
          """
        }
      }
    }

    stage('Deploying to K8s') {
      environment {
        MY_KUBECONFIG = credentials('kubeconfig-admin')     //操作k8s的kubeconfig文件,也是放在Jenkins的全局凭证里,这里写其id
    }
      steps {
        container(name: 'kubectl'){
           sh """
           #/usr/local/bin/kubectl --kubeconfig $MY_KUBECONFIG set image deploy -l app=${IMAGE_NAME} ${IMAGE_NAME}=${HARBOR_ADDRESS}/${REGISTRY_DIR}/${IMAGE_NAME}:${TAG} -n $NAMESPACE
           /usr/local/bin/kubectl --kubeconfig $MY_KUBECONFIG set image deploy -l app=${IMAGE_NAME} ${IMAGE_NAME}=${HARBOR_ADDRESS}/${REGISTRY_DIR}/${IMAGE_NAME}:${TAG} -n $NAMESPACE
           """
        }
      }
    }

  }
  environment {                               //!!!顶层环境变量定义!!!
    COMMIT_ID = ""
    HARBOR_ADDRESS = "10.201.83.230:30002"    //我的镜像的名称 和我的容器名称 和deploy(pod控制器)的label,是一致的    //dukuan cicd 经验
    REGISTRY_DIR = "kubernetes"             //harbor 仓库名字
    IMAGE_NAME = "spring-boot-project"
    NAMESPACE = "kubernetes"
    TAG = ""                 //写道顶层全局变量里所有stage就都能读到了,!   TAG 在 dockers build 和 images push 等多个环节用到了,所以需要写道顶层全局变量里,!  一开始TAG是空值,dockers build 重新给赋值,//images push 的时候就可以直接用了!
  }
  parameters {               //参数化构建过程   //这里指定了代码分支
    gitParameter(branch: '', branchFilter: 'origin/(.*)', defaultValue: '', description: 'Branch for build and deploy', name: 'BRANCH', quickFilterEnabled: false, selectedValue: 'NONE', sortMode: 'NONE', tagFilter: '*', type: 'PT_BRANCH')
  }
}
