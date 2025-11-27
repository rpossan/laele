class LocalesController < ApplicationController
  def update
    locale = params[:locale].to_sym
    
    if I18n.available_locales.include?(locale)
      session[:locale] = locale
      I18n.locale = locale
      redirect_back(fallback_location: root_path, notice: t('messages.success'))
    else
      redirect_back(fallback_location: root_path, alert: t('errors.invalid_locale'))
    end
  end
end

