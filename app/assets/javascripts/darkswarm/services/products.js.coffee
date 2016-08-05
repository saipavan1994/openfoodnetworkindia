Darkswarm.factory 'Products', ($resource, Enterprises, Dereferencer, Taxons, Properties, Cart, Variants) ->
  new class Products
    constructor: ->
      @update()

    # TODO: don't need to scope this into object
    # Already on object as far as controller scope is concerned
    products: null
    loading: true

    update: =>
      @loading = true
      @products = []
      $resource("/shop/products").query (products)=>
        @products = products

        @extend()
        @dereference()
        @registerVariants()
        @registerVariantsWithCart()
        @loading = false

    extend: ->
      for product in @products
        if product.variants?.length > 0
          prices = (v.price for v in product.variants)
          product.price = Math.min.apply(null, prices)
        product.hasVariants = product.variants?.length > 0

        product.primaryImage = product.images[0]?.small_url if product.images
        product.primaryImageOrMissing = product.primaryImage || "/assets/noimage/small.png"
        product.largeImage = product.images[0]?.large_url if product.images

    dereference: ->
      for product in @products
        product.supplier = Enterprises.enterprises_by_id[product.supplier.id]
        Dereferencer.dereference product.taxons, Taxons.taxons_by_id

        product.properties = angular.copy(product.properties_with_values)
        Dereferencer.dereference product.properties, Properties.properties_by_id

    # May return different objects! If the variant has already been registered
    # by another service, we fetch those
    registerVariants: ->
      for product in @products
        if product.variants
          product.variants = (Variants.register variant for variant in product.variants)
          variant.product = product for variant in product.variants
        if product.master
          product.master.product = product
          product.master = Variants.register product.master

    registerVariantsWithCart: ->
      for product in @products
        if product.variants
          for variant in product.variants
            Cart.register_variant variant
        Cart.register_variant product.master if product.master
