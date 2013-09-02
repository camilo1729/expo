--- !ruby/object:ResourceSet
type: :resource_set
properties:
  :name: Exp_resources
  :gateway: grenoble.g5k
resources:
- !ruby/object:ResourceSet
  type: :site
  properties:
    :name: grenoble
    :gateway: frontend.grenoble.grid5000.fr
    :ssh_user: cruizsanabria
  resources:
  - !ruby/object:ResourceSet
    type: :cluster
    properties:
      :id: 1496006
      :name: genepi
      :gateway: frontend.grenoble.grid5000.fr
      :ssh_user: cruizsanabria
      :gw_ssh_user: cruizsanabria
    resources:
    - !ruby/object:Resource
      type: :node
      properties:
        :name: genepi-25.grenoble.grid5000.fr
        :gateway: frontend.grenoble.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: genepi-28.grenoble.grid5000.fr
        :gateway: frontend.grenoble.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: genepi-33.grenoble.grid5000.fr
        :gateway: frontend.grenoble.grid5000.fr
    resource_files: {}
  - !ruby/object:ResourceSet
    type: :cluster
    properties:
      :id: 1496007
      :name: edel
      :gateway: frontend.grenoble.grid5000.fr
      :ssh_user: cruizsanabria
      :gw_ssh_user: cruizsanabria
    resources:
    - !ruby/object:Resource
      type: :node
      properties:
        :name: edel-46.grenoble.grid5000.fr
        :gateway: frontend.grenoble.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: edel-58.grenoble.grid5000.fr
        :gateway: frontend.grenoble.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: edel-59.grenoble.grid5000.fr
        :gateway: frontend.grenoble.grid5000.fr
    resource_files: {}
  - !ruby/object:ResourceSet
    type: :cluster
    properties:
      :id: 1496008
      :name: adonis
      :gateway: frontend.grenoble.grid5000.fr
      :ssh_user: cruizsanabria
      :gw_ssh_user: cruizsanabria
    resources:
    - !ruby/object:Resource
      type: :node
      properties:
        :name: adonis-7.grenoble.grid5000.fr
        :gateway: frontend.grenoble.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: adonis-8.grenoble.grid5000.fr
        :gateway: frontend.grenoble.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: adonis-9.grenoble.grid5000.fr
        :gateway: frontend.grenoble.grid5000.fr
    resource_files: {}
  resource_files: {}
- !ruby/object:ResourceSet
  type: :site
  properties:
    :name: lille
    :gateway: frontend.lille.grid5000.fr
    :ssh_user: cruizsanabria
  resources:
  - !ruby/object:ResourceSet
    type: :cluster
    properties:
      :id: 1318784
      :name: chirloute
      :gateway: frontend.lille.grid5000.fr
      :ssh_user: cruizsanabria
      :gw_ssh_user: cruizsanabria
    resources:
    - !ruby/object:Resource
      type: :node
      properties:
        :name: chirloute-5.lille.grid5000.fr
        :gateway: frontend.lille.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: chirloute-7.lille.grid5000.fr
        :gateway: frontend.lille.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: chirloute-8.lille.grid5000.fr
        :gateway: frontend.lille.grid5000.fr
    resource_files: {}
  - !ruby/object:ResourceSet
    type: :cluster
    properties:
      :id: 1318785
      :name: chimint
      :gateway: frontend.lille.grid5000.fr
      :ssh_user: cruizsanabria
      :gw_ssh_user: cruizsanabria
    resources:
    - !ruby/object:Resource
      type: :node
      properties:
        :name: chimint-16.lille.grid5000.fr
        :gateway: frontend.lille.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: chimint-19.lille.grid5000.fr
        :gateway: frontend.lille.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: chimint-9.lille.grid5000.fr
        :gateway: frontend.lille.grid5000.fr
    resource_files: {}
  - !ruby/object:ResourceSet
    type: :cluster
    properties:
      :id: 1318783
      :name: chinqchint
      :gateway: frontend.lille.grid5000.fr
      :ssh_user: cruizsanabria
      :gw_ssh_user: cruizsanabria
    resources:
    - !ruby/object:Resource
      type: :node
      properties:
        :name: chinqchint-27.lille.grid5000.fr
        :gateway: frontend.lille.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: chinqchint-40.lille.grid5000.fr
        :gateway: frontend.lille.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: chinqchint-41.lille.grid5000.fr
        :gateway: frontend.lille.grid5000.fr
    resource_files: {}
  resource_files: {}
- !ruby/object:ResourceSet
  type: :site
  properties:
    :name: nancy
    :gateway: frontend.nancy.grid5000.fr
    :ssh_user: cruizsanabria
  resources:
  - !ruby/object:ResourceSet
    type: :cluster
    properties:
      :id: 483695
      :name: griffon
      :gateway: frontend.nancy.grid5000.fr
      :ssh_user: cruizsanabria
      :gw_ssh_user: cruizsanabria
    resources:
    - !ruby/object:Resource
      type: :node
      properties:
        :name: griffon-11.nancy.grid5000.fr
        :gateway: frontend.nancy.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: griffon-12.nancy.grid5000.fr
        :gateway: frontend.nancy.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: griffon-13.nancy.grid5000.fr
        :gateway: frontend.nancy.grid5000.fr
    resource_files: {}
  - !ruby/object:ResourceSet
    type: :cluster
    properties:
      :id: 483694
      :name: graphene
      :gateway: frontend.nancy.grid5000.fr
      :ssh_user: cruizsanabria
      :gw_ssh_user: cruizsanabria
    resources:
    - !ruby/object:Resource
      type: :node
      properties:
        :name: graphene-57.nancy.grid5000.fr
        :gateway: frontend.nancy.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: graphene-58.nancy.grid5000.fr
        :gateway: frontend.nancy.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: graphene-81.nancy.grid5000.fr
        :gateway: frontend.nancy.grid5000.fr
    resource_files: {}
  resource_files: {}
- !ruby/object:ResourceSet
  type: :site
  properties:
    :name: lyon
    :gateway: frontend.lyon.grid5000.fr
    :ssh_user: cruizsanabria
  resources:
  - !ruby/object:ResourceSet
    type: :cluster
    properties:
      :id: 672375
      :name: orion
      :gateway: frontend.lyon.grid5000.fr
      :ssh_user: cruizsanabria
      :gw_ssh_user: cruizsanabria
    resources:
    - !ruby/object:Resource
      type: :node
      properties:
        :name: orion-2.lyon.grid5000.fr
        :gateway: frontend.lyon.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: orion-3.lyon.grid5000.fr
        :gateway: frontend.lyon.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: orion-4.lyon.grid5000.fr
        :gateway: frontend.lyon.grid5000.fr
    resource_files: {}
  - !ruby/object:ResourceSet
    type: :cluster
    properties:
      :id: 672378
      :name: sagittaire
      :gateway: frontend.lyon.grid5000.fr
      :ssh_user: cruizsanabria
      :gw_ssh_user: cruizsanabria
    resources:
    - !ruby/object:Resource
      type: :node
      properties:
        :name: sagittaire-57.lyon.grid5000.fr
        :gateway: frontend.lyon.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: sagittaire-7.lyon.grid5000.fr
        :gateway: frontend.lyon.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: sagittaire-9.lyon.grid5000.fr
        :gateway: frontend.lyon.grid5000.fr
    resource_files: {}
  - !ruby/object:ResourceSet
    type: :cluster
    properties:
      :id: 672377
      :name: taurus
      :gateway: frontend.lyon.grid5000.fr
      :ssh_user: cruizsanabria
      :gw_ssh_user: cruizsanabria
    resources:
    - !ruby/object:Resource
      type: :node
      properties:
        :name: taurus-3.lyon.grid5000.fr
        :gateway: frontend.lyon.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: taurus-4.lyon.grid5000.fr
        :gateway: frontend.lyon.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: taurus-6.lyon.grid5000.fr
        :gateway: frontend.lyon.grid5000.fr
    resource_files: {}
  - !ruby/object:ResourceSet
    type: :cluster
    properties:
      :id: 672376
      :name: hercule
      :gateway: frontend.lyon.grid5000.fr
      :ssh_user: cruizsanabria
      :gw_ssh_user: cruizsanabria
    resources:
    - !ruby/object:Resource
      type: :node
      properties:
        :name: hercule-2.lyon.grid5000.fr
        :gateway: frontend.lyon.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: hercule-3.lyon.grid5000.fr
        :gateway: frontend.lyon.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: hercule-4.lyon.grid5000.fr
        :gateway: frontend.lyon.grid5000.fr
    resource_files: {}
  resource_files: {}
- !ruby/object:ResourceSet
  type: :site
  properties:
    :name: rennes
    :gateway: frontend.rennes.grid5000.fr
    :ssh_user: cruizsanabria
  resources:
  - !ruby/object:ResourceSet
    type: :cluster
    properties:
      :id: 547049
      :name: parapide
      :gateway: frontend.rennes.grid5000.fr
      :ssh_user: cruizsanabria
      :gw_ssh_user: cruizsanabria
    resources:
    - !ruby/object:Resource
      type: :node
      properties:
        :name: parapide-13.rennes.grid5000.fr
        :gateway: frontend.rennes.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: parapide-15.rennes.grid5000.fr
        :gateway: frontend.rennes.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: parapide-16.rennes.grid5000.fr
        :gateway: frontend.rennes.grid5000.fr
    resource_files: {}
  - !ruby/object:ResourceSet
    type: :cluster
    properties:
      :id: 547050
      :name: paradent
      :gateway: frontend.rennes.grid5000.fr
      :ssh_user: cruizsanabria
      :gw_ssh_user: cruizsanabria
    resources:
    - !ruby/object:Resource
      type: :node
      properties:
        :name: paradent-6.rennes.grid5000.fr
        :gateway: frontend.rennes.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: paradent-7.rennes.grid5000.fr
        :gateway: frontend.rennes.grid5000.fr
    - !ruby/object:Resource
      type: :node
      properties:
        :name: paradent-9.rennes.grid5000.fr
        :gateway: frontend.rennes.grid5000.fr
    resource_files: {}
  resource_files: {}
resource_files: {}
