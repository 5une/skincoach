class ShopController < ApplicationController
  def index
    @products = Product.all
    @categories = Product.distinct.pluck(:category).compact.sort
    @brands = Product.distinct.pluck(:brand).compact.sort
    
    # Filter products based on parameters
    if params[:category].present?
      @products = @products.where(category: params[:category])
    end
    
    if params[:brand].present?
      @products = @products.where(brand: params[:brand])
    end
    
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @products = @products.where(
        "name ILIKE ? OR brand ILIKE ? OR key_ingredients ILIKE ? OR skin_concerns ILIKE ?",
        search_term, search_term, search_term, search_term
      )
    end
    
    # Sort products
    case params[:sort]
    when 'price_low'
      @products = @products.order(:price)
    when 'price_high'
      @products = @products.order(price: :desc)
    when 'brand'
      @products = @products.order(:brand, :name)
    else
      @products = @products.order(:name)
    end
    
    @products = @products.page(params[:page]).per(12) if respond_to?(:page)
  end
end
