class SceneKeeper
  visualStructure = require './visualStructure'
  geometryBuilder = require './geometryBuilder'

  SHOW_STATS = true

  constructor: ->
    @selectedArtistMaterial = new THREE.MeshLambertMaterial({
      opacity: 0.50
      wireframe: false
      transparent:true
    })


  init:(data) ->
    @data = data
    visualStructure.init(data)
    @initScene()
    geometryBuilder.build(@scene, @data)

  initScene: ->

    @scene = new THREE.Scene

    WIDTH = window.innerWidth || 2;
    HEIGHT = window.innerHeight || ( 2 + 2 * MARGIN );

    MARGIN = 0
    SCREEN_WIDTH = WIDTH
    SCREEN_HEIGHT = HEIGHT - 2 * MARGIN

    FAR = 10000

    @camera = new THREE.PerspectiveCamera(35, SCREEN_WIDTH / SCREEN_HEIGHT, 0.1, FAR)
    @camera.position.set(-190,75,0)
    @camera.lookAt(@scene.position);

    @controls = new THREE.TrackballControls(@camera)
    @controls.rotateSpeed = 1.0
    @controls.zoomSpeed = 1.2
    @controls.panSpeed = 0.8
    @controls.noZoom = false
    @controls.noPan = false
    @controls.staticMoving = false
    @controls.dynamicDampingFactor = 0.3
    @controls.keys = [ 65, 83, 68 ]

    # @scene.fog = new THREE.FogExp2 0xcccccc, 0.001103

    # geometry = new THREE.CubeGeometry( 1, 1, 1 )
    # material = new THREE.MeshLambertMaterial( { color: 0xFF0000 } )
    # mesh = new THREE.Mesh( geometry, material )
    # @scene.add( mesh )

    # light = new THREE.PointLight( 0xFFFFFF )
    # light.position.set( 0, 0, 40 )
    # @scene.add( light )

    @scene.add( new THREE.AmbientLight( 0x808080 ) )

    light = new THREE.SpotLight( 0xffffff, 1.0 )
    light.position.set( 50, 150, 0 )
    light.castShadow = true

    light.shadowCameraNear = 100
    light.shadowCameraFar = @camera.far
    light.shadowCameraFov = 100

    light.shadowBias = -0.00122
    light.shadowDarkness = 0.1

    light.shadowMapWidth = 4096
    light.shadowMapHeight = 4096
    @scene.add(light)


    light = new THREE.SpotLight( 0xffffff, 0.6 )
    light.position.set( 50, 150, 100 )
    # light.castShadow = false

    # light.shadowCameraNear = 100
    # light.shadowCameraFar = @camera.far
    # light.shadowCameraFov = 100

    # light.shadowBias = -0.00122
    # light.shadowDarkness = 0.8

    # light.shadowMapWidth = 4096
    # light.shadowMapHeight = 4096
    @scene.add(light)

    @renderer = new THREE.WebGLRenderer({ antialias: true})
    @renderer.setSize(SCREEN_WIDTH, SCREEN_HEIGHT)
    @renderer.setClearColor(new THREE.Color(0xD0D0D8))

    @renderer.shadowMapEnabled = true;
    @renderer.shadowMapType = THREE.PCFShadowMap;
    @renderer.sortObjects = false;
    
    # Composer

    @renderer.autoClear = false;

    renderTargetParameters = { minFilter: THREE.LinearFilter, magFilter: THREE.LinearFilter, format: THREE.RGBFormat, stencilBuffer: false }
    @renderTarget = new THREE.WebGLRenderTarget( SCREEN_WIDTH * 2, SCREEN_HEIGHT * 2, renderTargetParameters )

    # effectFXAA = new THREE.ShaderPass( THREE.FXAAShader )
    # effectFXAA.uniforms[ 'resolution' ].value.set( 1 / SCREEN_WIDTH / 2, 1 / SCREEN_HEIGHT / 2 )

    effectVignette = new THREE.ShaderPass( THREE.VignetteShader )
    effectVignette.uniforms[ 'darkness' ].value = 0.4

    hblur = new THREE.ShaderPass( THREE.HorizontalTiltShiftShader )
    vblur = new THREE.ShaderPass( THREE.VerticalTiltShiftShader )
    bluriness = 2
    hblur.uniforms[ 'h' ].value = bluriness / SCREEN_WIDTH
    vblur.uniforms[ 'v' ].value = bluriness / SCREEN_HEIGHT
    hblur.uniforms[ 'r' ].value = vblur.uniforms[ 'r' ].value = 0.5

    @composer = new THREE.EffectComposer( @renderer, @renderTarget )
    renderModel = new THREE.RenderPass( @scene, @camera )

    @composer.addPass(renderModel)
    @composer.addPass(effectVignette);
    @composer.addPass(hblur);
    @composer.addPass(vblur);
    # @composer.addPass(effectFXAA)
    vblur.renderToScreen = true;

    container = document.createElement('div')
    document.body.appendChild(container)
    container.appendChild(@renderer.domElement)

    if SHOW_STATS
      @stats = new Stats()
      @stats.domElement.style.position = 'absolute'
      @stats.domElement.style.top = '0px'
      @stats.domElement.style.left = '0px'
      container.appendChild(@stats.domElement)        

    @mouse = new THREE.Vector2()
    @projector = new THREE.Projector()
    @animate()

    window.addEventListener('dblclick', @click, false)
    window.addEventListener('mousemove', @mousemove, false)
    window.addEventListener('resize', @resize, false)
    window.addEventListener('resize', @resize, false)

    @currentArtist = undefined

  resize: =>
    SCREEN_WIDTH = window.innerWidth
    SCREEN_HEIGHT = window.innerHeight

    @renderer.setSize( SCREEN_WIDTH, SCREEN_HEIGHT )

    @camera.aspect = SCREEN_WIDTH / SCREEN_HEIGHT
    @camera.updateProjectionMatrix()

  click:(event) =>
    res = @findArtist(event)

    if ! res?
      if @currentArtist
        @currentArtist = undefined
        @scene.remove(@currentArtistMesh)
        $(".container h2").removeClass("selected")
        vec = new THREE.Vector3();
        vec.subVectors( @camera.position, @controls.target);
        vec.setLength(vec.length() * 3);
        vec.addVectors(vec, @controls.target)
        @tweenCamera(vec, @controls.target)
    else
      $(".container h2").addClass("selected")
      @currentArtist = res.artist
      @updateArtistName(@currentArtist)

      # Color chosen mesh
      if @currentArtistMesh
        @scene.remove(@currentArtistMesh)

      mesh = geometryBuilder.artistMesh(res.artist, @selectedArtistMaterial, 1.03)
      @scene.add(mesh)
      @currentArtistMesh = mesh

      oldLookAt = @controls.target
      lookAt = res.artist.focusFace.centroid.clone()
      v = new THREE.Vector3();
      v.subVectors(lookAt,@controls.target);
      # @controls.target.set(lookAt.x,lookAt.y,lookAt.z)

      size = 1 + res.artist._height * 160
      distToCenter = size/Math.sin( Math.PI / 180.0 * @camera.fov * 0.5)
      vec = new THREE.Vector3()
      vec.subVectors(@camera.position, oldLookAt)
      vec.setLength(distToCenter);
      vec.addVectors(vec, lookAt)
      @tweenCamera(vec, lookAt)

  tweenCamera:(position, target) =>
    TWEEN.removeAll()
    new TWEEN.Tween(@camera.position ).to( {
    x: position.x,
    y: position.y,
    z: position.z}, 1000 )
    .easing( TWEEN.Easing.Exponential.Out).start()
    new TWEEN.Tween(@controls.target ).to( {
    x: target.x,
    y: target.y,
    z: target.z}, 800 )
    .easing( TWEEN.Easing.Exponential.Out).start()

  findArtist:(event) ->
    @mouse.x = ( event.clientX / window.innerWidth ) * 2 - 1
    @mouse.y = - ( event.clientY / window.innerHeight ) * 2 + 1
    vector = new THREE.Vector3(@mouse.x, @mouse.y, 0.5)
    @projector.unprojectVector(vector, @camera)
    ray = new THREE.Raycaster(@camera.position, vector.sub(@camera.position ).normalize())
    intersects = ray.intersectObjects(@scene.children)

    if intersects.length > 0
      face = intersects[0].face
      artist = @data.artistsKeyed[face.color.r]
      res =
        object: intersects[0]
        artist: artist
        face:   face 
      return res
    return undefined

  mousemove:(event) =>
    return if @currentArtist?
    res = @findArtist(event)
    if res?
      @updateArtistName(res.artist)
    else
      @blankArtistName()

  blankArtistName:() =>
    $('.container h2').text("")
    $('.container p').text("")

  updateArtistName:(artist) =>
    $('.container h2').text(artist.firstname + " " + artist.lastname)
    dod = if artist.dod == 2013 then "" else artist.dod
    $('.container p').text(artist.dob + " - " + dod)

  animate: ->
    @render()
    @stats.update() if SHOW_STATS
    requestAnimationFrame(=> @animate()) unless @stopped
    TWEEN.update();
    @controls.update();

  render: ->
    @composer.render()

module.exports = new SceneKeeper
