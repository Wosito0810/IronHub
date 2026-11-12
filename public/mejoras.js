/* IRONHUB 2.0 · UI adicional sin reemplazar las funciones del proyecto original. */
const GRUPOS_IRONHUB = [
  [1, 'Glúteos y femorales'], [2, 'Cuádriceps'], [3, 'Pantorrillas'],
  [4, 'Pecho'], [5, 'Espalda'], [6, 'Hombros'], [7, 'Bíceps'],
  [8, 'Tríceps'], [9, 'Abdominales']
];
let mediosAprobados = new Map();
let temporalPreview = null;
const temporalAdmin = new Map();

function slugDemo(nombre) {
  if (typeof DEMO_EJERCICIOS === 'undefined') return '';
  const clave = Object.keys(DEMO_EJERCICIOS).find(
    k => k.toLowerCase() === String(nombre || '').toLowerCase());
  return clave ? (DEMO_EJERCICIOS[clave].demo || '') : '';
}
function rutaImagenEjercicio(ejercicio) {
  if (ejercicio && mediosAprobados.has(Number(ejercicio.id_ejercicio))) {
    const medio = mediosAprobados.get(Number(ejercicio.id_ejercicio));
    if (medio.tipo_media === 'imagen')
      return `${API_BASE}/propuestas/${medio.id_propuesta}/archivo-publico`;
  }
  const slug = slugDemo(typeof ejercicio === 'string' ? ejercicio : ejercicio && ejercicio.nombre);
  return slug ? `assets/ejercicios/${encodeURIComponent(slug)}/0.jpg` : 'assets/ejercicio-fallback.svg';
}
function cambiarImagenAlternativa(imagen) {
  // Solo intenta el CDN una vez. Si falla, usa un SVG integrado sin imagen rota.
  const fase = imagen.dataset.fase || 'local';
  const slug = imagen.dataset.slug;
  if (fase === 'local' && slug && typeof DEMO_EJERCICIOS_BASE === 'string') {
    imagen.dataset.fase = 'externa';
    const numero = imagen.dataset.numero || '0';
    imagen.src = DEMO_EJERCICIOS_BASE + encodeURIComponent(slug) + '/' + numero + '.jpg';
  } else if (fase === 'externa' && slug) {
    imagen.dataset.fase = 'alternativa';
    const numero = imagen.dataset.numero || '0';
    imagen.src = 'https://cdn.jsdelivr.net/gh/yuhonas/free-exercise-db@main/exercises/' +
      encodeURIComponent(slug) + '/' + numero + '.jpg';
  } else {
    imagen.onerror = null;
    imagen.dataset.fase = 'respaldo';
    imagen.src = 'assets/ejercicio-fallback.svg';
    imagen.classList.add('imagen-fallback');
  }
}
function miniaturaHtml(ejercicio, clase='ejercicio-miniatura') {
  const slug = slugDemo(ejercicio.nombre);
  return `<img class="${clase}" src="${esc(rutaImagenEjercicio(ejercicio))}"
      data-slug="${esc(slug)}" data-numero="0"
      alt="Demostración de ${esc(ejercicio.nombre)}"
      onerror="cambiarImagenAlternativa(this)" loading="lazy">`;
}
function cambiarPestana(id) {
  switchTab(id, document.querySelector(`.tab-btn[data-tab="${id}"]`));
}
function obtenerFavoritos() {
  try { return JSON.parse(localStorage.getItem('ironhub_favoritos_' + (usuarioActual?.id_usuario || 'anon')) || '[]'); }
  catch { return []; }
}
function cambiarFavorito(id) {
  const listado = new Set(obtenerFavoritos().map(Number));
  listado.has(Number(id)) ? listado.delete(Number(id)) : listado.add(Number(id));
  localStorage.setItem('ironhub_favoritos_' + (usuarioActual?.id_usuario || 'anon'), JSON.stringify([...listado]));
  renderBiblioteca();
}
async function cargarMediosAprobados() {
  const resultado = await apiFetch('/propuestas/medios-aprobados');
  mediosAprobados = new Map((resultado.medios || []).map(m => [Number(m.id_ejercicio), m]));
}
function renderBiblioteca() {
  const zona = document.getElementById('biblioteca-lista');
  if (!zona) return;
  const texto = (document.getElementById('biblioteca-buscar')?.value || '').trim().toLocaleLowerCase('es');
  const grupo = document.getElementById('biblioteca-grupo')?.value || '';
  const soloFavoritos = document.getElementById('biblioteca-favoritos')?.checked;
  const favoritos = new Set(obtenerFavoritos().map(Number));
  const visibles = catalogoEjercicios.filter(e =>
    (!texto || `${e.nombre} ${e.grupo_muscular} ${e.descripcion || ''}`.toLocaleLowerCase('es').includes(texto)) &&
    (!grupo || String(e.id_grupo) === grupo) &&
    (!soloFavoritos || favoritos.has(Number(e.id_ejercicio))));
  document.getElementById('biblioteca-contador').textContent = `${visibles.length} de ${catalogoEjercicios.length} ejercicios`;
  zona.innerHTML = visibles.length ? visibles.map(e => `
    <article class="card-option biblioteca-card">
      ${miniaturaHtml(e,'biblioteca-img')}
      <div class="biblioteca-card-cuerpo">
        <small>${esc(e.grupo_muscular)}</small>
        <h4>${esc(e.nombre)}</h4>
        <p>${esc(e.descripcion || 'Ver la guía para conocer la técnica.')}</p>
        <div class="biblioteca-acciones">
          <button class="btn-mini ver-ejercicio" data-abrir="${Number(e.id_ejercicio)}">Ver técnica</button>
          <button class="btn-mini" data-fav="${Number(e.id_ejercicio)}"
              aria-label="${favoritos.has(Number(e.id_ejercicio)) ? 'Quitar de favoritos':'Añadir a favoritos'}"
              title="Guardar entre tus favoritos">${favoritos.has(Number(e.id_ejercicio)) ? '★ Guardado':'☆ Favorito'}</button>
        </div>
      </div>
    </article>`).join('') : '<div class="empty-state">No encontramos ejercicios con ese filtro. Prueba otra búsqueda.</div>';
  zona.querySelectorAll('[data-abrir]').forEach(b => b.addEventListener('click', () => {
    const ej = catalogoEjercicios.find(e => Number(e.id_ejercicio) === Number(b.dataset.abrir));
    if (ej) abrirDemoEjercicio(ej, b);
  }));
  zona.querySelectorAll('[data-fav]').forEach(b => b.addEventListener('click', () => cambiarFavorito(b.dataset.fav)));
}
function filtrarCatalogoPlan() {
  const texto = (document.getElementById('buscar-catalogo-plan')?.value || '').toLocaleLowerCase('es').trim();
  let total = 0;
  document.querySelectorAll('#catalogo-por-grupos-container .grupo-grupo-container').forEach(grupo => {
    let cantidad = 0;
    grupo.querySelectorAll('.ejercicio-item').forEach(item => {
      const seVe = !texto || item.textContent.toLocaleLowerCase('es').includes(texto);
      item.style.display = seVe ? '' : 'none';
      if (seVe) cantidad++;
    });
    grupo.style.display = cantidad ? '' : 'none';
    total += cantidad;
  });
  const marcador = document.getElementById('catalogo-plan-contador');
  if (marcador) marcador.textContent = `${total} resultados`;
}
async function actualizarMetricas() {
  const metricCatalogo = document.getElementById('metrica-ejercicios');
  if (metricCatalogo) metricCatalogo.textContent = catalogoEjercicios.length;
  const metricPlanes = document.getElementById('metrica-planes');
  if (metricPlanes) metricPlanes.textContent = misRutinas.length;
  try {
    const datos = await apiFetch('/asistencia/mia');
    document.getElementById('metrica-asistencias').textContent = datos.total || 0;
    const caja = document.getElementById('historial-asistencias');
    caja.innerHTML = datos.historial?.length ? `
      <h4 style="margin:20px 0 9px">Mis últimos registros</h4>
      <div class="historial-grid">${datos.historial.map(a=>`<div>✓ ${esc(a.fecha)} · ${esc(a.fecha_hora.slice(11,16))}</div>`).join('')}</div>`:
      '<p class="mini-note">Aún no has registrado asistencias.</p>';
  } catch (e) {
    document.getElementById('historial-asistencias').textContent = e.message;
  }
}
function abrirAyuda() {
  const panel = document.getElementById('ayuda-panel');
  panel.hidden = !panel.hidden;
  document.getElementById('boton-ayuda').setAttribute('aria-expanded', String(!panel.hidden));
}
function rellenarGrupos() {
  document.getElementById('propuesta-grupo').innerHTML = '<option value="">Selecciona una opción</option>' +
    GRUPOS_IRONHUB.map(([id,n])=>`<option value="${id}">${esc(n)}</option>`).join('');
  document.getElementById('biblioteca-grupo').innerHTML = '<option value="">Todos los grupos</option>' +
    GRUPOS_IRONHUB.map(([id,n])=>`<option value="${id}">${esc(n)}</option>`).join('');
}
function previewArchivo(evento) {
  if (temporalPreview) URL.revokeObjectURL(temporalPreview);
  temporalPreview = null;
  const archivo = evento.target.files?.[0];
  const zona = document.getElementById('propuesta-preview-local');
  zona.innerHTML = '';
  if (!archivo) return;
  if (archivo.size > 25*1024*1024) {
    mostrarToast('El archivo supera 25 MB.', 'error'); evento.target.value = ''; return;
  }
  temporalPreview = URL.createObjectURL(archivo);
  if (archivo.type.startsWith('image/')) {
    const img = document.createElement('img'); img.src = temporalPreview; img.alt = 'Vista previa de la foto seleccionada'; img.className = 'propuesta-preview'; zona.append(img);
  } else if (archivo.type.startsWith('video/')) {
    const video = document.createElement('video'); video.src = temporalPreview; video.controls = true; video.preload = 'metadata'; video.className = 'propuesta-preview'; zona.append(video);
  }
}
async function enviarPropuesta(evento) {
  evento.preventDefault();
  const form = evento.currentTarget;
  const boton = document.getElementById('enviar-propuesta');
  const archivo = document.getElementById('propuesta-archivo').files?.[0];
  if (!archivo) { mostrarToast('Adjunta una imagen o video.', 'error'); return; }
  if (archivo.size > 25*1024*1024) {mostrarToast('El archivo supera 25 MB.', 'error');return;}
  const datos = new FormData(form);
  boton.disabled = true; boton.textContent = 'Enviando propuesta…';
  try {
    const resultado = await apiFetch('/propuestas',{method:'POST',body:datos});
    mostrarToast(resultado.mensaje,'success'); form.reset();
    document.getElementById('propuesta-preview-local').innerHTML = '';
    if (temporalPreview) URL.revokeObjectURL(temporalPreview); temporalPreview=null;
    await cargarMisPropuestas();
  } catch(e) { mostrarToast(e.message,'error'); }
  finally { boton.disabled=false; boton.textContent='Enviar propuesta para revisión'; }
}
function tarjetaPropuesta(p, esAdmin=false) {
  return `<div class="propuesta-card">
    <strong>${esc(p.nombre)}</strong>
    <span class="etiqueta-estado ${esc(p.estado)}">${esc(p.estado)}</span>
    <p>${esc(p.descripcion)}</p>
    <div class="muted">${esc(p.grupo_muscular)} · ${esc(p.fecha_envio?.replace('T',' ').slice(0,16) || '')}${esAdmin ? ' · Enviado por '+esc(p.autor):''}</div>
    <div class="archivo-propuesta" data-id="${Number(p.id_propuesta)}" data-media="${esc(p.tipo_media)}"></div>
    ${esAdmin?`<div class="biblioteca-acciones" style="margin-top:12px"><button class="btn-mini" data-revisar="${Number(p.id_propuesta)}" data-decision="APROBADA">Aprobar</button><button class="btn-mini peligro" data-revisar="${Number(p.id_propuesta)}" data-decision="RECHAZADA">Rechazar</button></div>`:''}
  </div>`;
}
async function renderMediaPropuestas(contenedor) {
  // Solo descarga el adjunto cuando el usuario pide verlo; evita cargar
  // decenas de videos durante la moderación.
  (temporalAdmin.get(contenedor) || []).forEach(u => URL.revokeObjectURL(u));
  temporalAdmin.set(contenedor, []);
  contenedor.querySelectorAll('.archivo-propuesta').forEach(el => {
    const boton = document.createElement('button');
    boton.type='button'; boton.className='btn-mini';
    boton.style.marginTop='10px'; boton.textContent='Ver foto / video adjunto';
    el.append(boton);
    boton.addEventListener('click', async () => {
      boton.disabled=true; boton.textContent='Cargando archivo…';
      try {
        const id = Number(el.dataset.id);
        const resp = await fetch(`${API_BASE}/propuestas/${id}/archivo`, {
          headers: {'Authorization': 'Bearer '+token}
        });
        if (!resp.ok) throw new Error('No disponible');
        const blob = await resp.blob();
        const url = URL.createObjectURL(blob);
        temporalAdmin.get(contenedor).push(url);
        const item = document.createElement(el.dataset.media === 'video'?'video':'img');
        item.src=url; item.className='propuesta-preview';
        if (el.dataset.media === 'video') { item.controls=true; item.preload='metadata'; }
        else item.alt='Fotografía de la propuesta';
        boton.replaceWith(item);
      } catch (e) { boton.textContent='Error al cargar; reintentar'; boton.disabled=false; }
    });
  });
}
async function cargarMisPropuestas() {
  const caja = document.getElementById('lista-propuestas');
  caja.innerHTML = '<div class="loading">Consultando propuestas…</div>';
  try {
    const r = await apiFetch('/propuestas/mias');
    caja.innerHTML = r.propuestas.length ? r.propuestas.map(p=>tarjetaPropuesta(p)).join('') :
      '<div class="empty-state">Todavía no tienes propuestas. ¡Envía tu primera idea!</div>';
    await renderMediaPropuestas(caja);
  } catch(e) { caja.textContent=e.message; }
}
async function cargarPendientes() {
  const panel = document.getElementById('panel-moderacion');
  if (Number(usuarioActual?.id_rol) !== 1) {panel.hidden=true;return;}
  panel.hidden=false;
  const caja = document.getElementById('lista-pendientes');
  caja.innerHTML='<div class="loading">Cargando propuestas pendientes…</div>';
  try {
    const r = await apiFetch('/propuestas/pendientes');
    caja.innerHTML=r.propuestas.length?r.propuestas.map(p=>tarjetaPropuesta(p,true)).join(''):
      '<div class="empty-state">No hay propuestas pendientes.</div>';
    caja.querySelectorAll('[data-revisar]').forEach(b=>b.addEventListener('click',()=>revisarPropuesta(Number(b.dataset.revisar),b.dataset.decision)));
    await renderMediaPropuestas(caja);
  }catch(e){caja.textContent=e.message;}
}
async function revisarPropuesta(id, decision) {
  const acepto = await confirmar(`¿Quieres ${decision==='APROBADA'?'aprobar e incorporar al catálogo':'rechazar'} esta propuesta?`, decision==='APROBADA'?'Aprobar':'Rechazar');
  if (!acepto) return;
  try {
    const r = await apiFetch(`/propuestas/${id}/revision`, {method:'PATCH', body:JSON.stringify({decision})});
    mostrarToast(r.mensaje,'success');
    await cargarMediosAprobados(); await cargarCatalogo(); renderBiblioteca();
    await cargarPendientes(); await cargarMisPropuestas(); await actualizarMetricas();
  }catch(e){mostrarToast(e.message,'error');}
}
document.addEventListener('DOMContentLoaded', () => {
  rellenarGrupos();
  document.getElementById('form-propuesta').addEventListener('submit',enviarPropuesta);
  document.getElementById('propuesta-archivo').addEventListener('change',previewArchivo);
  document.getElementById('biblioteca-buscar').addEventListener('input', renderBiblioteca);
  document.getElementById('biblioteca-grupo').addEventListener('change', renderBiblioteca);
  document.getElementById('biblioteca-favoritos').addEventListener('change', renderBiblioteca);
  document.getElementById('buscar-catalogo-plan').addEventListener('input', filtrarCatalogoPlan);
  document.getElementById('boton-ayuda').addEventListener('click',abrirAyuda);
  document.getElementById('ayuda-cerrar').addEventListener('click',abrirAyuda);
});
