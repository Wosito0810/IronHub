/* IRONHUB 3.1 · Funcionalidades para clientes y administradores.
 * Mantiene las rutinas y el catálogo de IRONHUB 2.0 intactos.
 */
const $31 = id => document.getElementById(id);
const avisoError31 = e => mostrarToast(e?.message || 'No fue posible completar la operación.', 'error');
let clientesAdmin31 = [];
let cargandoAdmin31 = false;
const dias31 = ['','Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];

function sumarFila31(datos={}) {
  const zona = $31('filas-entrenamiento');
  if (zona.children.length >= 30) {mostrarToast('Máximo 30 ejercicios por sesión.','error'); return;}
  const fila = document.createElement('div');
  fila.className = 'fila-entrenamiento';
  fila.innerHTML = `<div class="form-group campo-ejercicio"><label>Ejercicio</label><select class="entreno-ejercicio" required>
      <option value="">Selecciona un ejercicio</option>
      ${catalogoEjercicios.map(e=>`<option value="${Number(e.id_ejercicio)}">${esc(e.nombre)}</option>`).join('')}
    </select></div>
    <div class="form-group"><label>Series</label><input class="entreno-series" type="number" value="3" min="1" max="99" required></div>
    <div class="form-group"><label>Repeticiones</label><input class="entreno-reps" type="number" value="10" min="1" max="999" required></div>
    <div class="form-group"><label>Peso (kg)</label><input class="entreno-peso" type="number" min="0" max="99999" step="0.25" placeholder="Opcional"></div>
    <button class="btn-mini peligro fila-quitar" type="button" aria-label="Quitar ejercicio">×</button>`;
  zona.append(fila);
  fila.querySelector('.entreno-ejercicio').value = String(datos.id_ejercicio||'');
  if(datos.series) fila.querySelector('.entreno-series').value = datos.series;
  if(datos.repeticiones) fila.querySelector('.entreno-reps').value = datos.repeticiones;
  fila.querySelector('.fila-quitar').addEventListener('click',()=>fila.remove());
}

async function usarRutinaDelDia31() {
  const dia = Number($31('entrenamiento-dia').value);
  try {
    const datos = await apiFetch(`/rutinas/dia/${dia}`);
    const lista = [...new Map((datos.rutinas||[]).flatMap(r=>r.ejercicios||[])
      .map(e=>[Number(e.id_ejercicio),e])).values()];
    if(!lista.length){mostrarToast('No hay ejercicios programados para ese día. Añádelos manualmente.','error');return;}
    $31('filas-entrenamiento').innerHTML='';
    lista.slice(0,30).forEach(sumarFila31);
    mostrarToast('Se cargaron los ejercicios de tu rutina del día. Ajusta lo que realizaste.');
  } catch(e){avisoError31(e);}
}

async function guardarEntrenamiento31(evento) {
  evento.preventDefault();
  const filas=[...$31('filas-entrenamiento').querySelectorAll('.fila-entrenamiento')];
  if(!filas.length){mostrarToast('Agrega un ejercicio antes de guardar.','error');return;}
  const ejercicios=filas.map(f=>({
    id_ejercicio:Number(f.querySelector('.entreno-ejercicio').value),
    series:Number(f.querySelector('.entreno-series').value),
    repeticiones:Number(f.querySelector('.entreno-reps').value),
    peso_kg:f.querySelector('.entreno-peso').value||null
  }));
  const boton=$31('guardar-entrenamiento');boton.disabled=true;
  try{
    const res=await apiFetch('/entrenamientos',{method:'POST', body:JSON.stringify({
      dia_semana:Number($31('entrenamiento-dia').value),
      notas:$31('entrenamiento-notas').value,
      ejercicios
    })});
    mostrarToast(res.mensaje);
    $31('entrenamiento-notas').value='';
    $31('filas-entrenamiento').innerHTML='';sumarFila31();
    await cargarEntrenamientos31();
  }catch(e){avisoError31(e);}finally{boton.disabled=false;}
}

async function cargarEntrenamientos31() {
  const caja=$31('lista-entrenamientos');
  caja.innerHTML='<div class="loading">Cargando tu actividad…</div>';
  try {
    const res=await apiFetch('/entrenamientos/mios');
    $31('metrica-sesiones').textContent=res.total||0;
    $31('metrica-semana').textContent=res.semana||0;
    $31('metrica-ultima').textContent=res.sesiones?.[0]?.fecha_hora?.slice(0,10)||'—';
    caja.innerHTML=res.sesiones?.length ? res.sesiones.map(s=>`
      <article class="entrenamiento-card">
        <div class="entrenamiento-encabezado"><strong>${esc(dias31[Number(s.dia_semana)]||'Sesión')}</strong><span>${esc(String(s.fecha_hora).replace('T',' ').slice(0,16))}</span></div>
        <ul>${(s.ejercicios||[]).map(e=>`<li><strong>${esc(e.nombre)}</strong><span>${Number(e.series)} × ${Number(e.repeticiones)}${e.peso_kg===null?'':` · ${Number(e.peso_kg)} kg`}</span></li>`).join('')}</ul>
        ${s.notas?`<p class="mini-note">${esc(s.notas)}</p>`:''}
      </article>`).join('') : '<div class="empty-state">Aún no tienes entrenamientos guardados. Registra tu primera sesión.</div>';
  }catch(e){caja.textContent=e.message;}
}

async function cargarPerfil31() {
  try{
    const {perfil}=await apiFetch('/mi-perfil');
    for(const field of ['nombre','apellido','email','telefono'])
      $31('perfil-'+field).value=perfil[field]||'';
  }catch(e){avisoError31(e);}
}
async function guardarPerfil31(evento){
  evento.preventDefault();
  const boton=$31('guardar-perfil');boton.disabled=true;
  try{
    const perfil=Object.fromEntries(['nombre','apellido','email','telefono'].map(k=>[k,$31('perfil-'+k).value]));
    const res=await apiFetch('/mi-perfil',{method:'PUT',body:JSON.stringify(perfil)});
    Object.assign(usuarioActual,res.perfil);
    localStorage.setItem('ironhub_usuario',JSON.stringify(usuarioActual));
    const badge=$31('user-info-badge');
    if(badge?.lastElementChild) badge.lastElementChild.textContent=`${usuarioActual.nombre} ${usuarioActual.apellido||''}`;
    mostrarToast(res.mensaje);
  }catch(e){avisoError31(e);}finally{boton.disabled=false;}
}
async function guardarClave31(evento){
  evento.preventDefault();
  const nueva=$31('clave-nueva').value;
  if(nueva!==$31('clave-confirmacion').value){mostrarToast('Las contraseñas nuevas no coinciden.','error');return;}
  const boton=$31('guardar-clave');boton.disabled=true;
  try{
    const r=await apiFetch('/mi-perfil/clave',{method:'PUT', body:JSON.stringify({actual:$31('clave-actual').value,nueva})});
    $31('form-contrasena').reset();mostrarToast(r.mensaje);
  }catch(e){avisoError31(e);}finally{boton.disabled=false;}
}

async function cargarAvisos31(){
  try{
    const r=await apiFetch('/notificaciones');
    const b=$31('contador-avisos');
    b.textContent=String(r.sin_leer||0);b.hidden=!r.sin_leer;
    $31('lista-notificaciones').innerHTML=r.notificaciones?.length?r.notificaciones.map(n=>`
      <article class="notificacion-card ${n.leida?'':'sin-leer'}">
        <div><strong>${esc(n.titulo)}</strong><p>${esc(n.mensaje)}</p><small>${esc(String(n.fecha_creacion).replace('T',' ').slice(0,16))}</small></div>
        ${n.leida?'':`<button class="btn-mini" data-avisoleido="${Number(n.id_notificacion)}">Marcar leída</button>`}
      </article>`).join(''):'<div class="empty-state">No tienes notificaciones. Aquí aparecerán las decisiones sobre tus propuestas.</div>';
    $31('lista-notificaciones').querySelectorAll('[data-avisoleido]').forEach(b=>b.addEventListener('click',async()=>{
      try{await apiFetch(`/notificaciones/${Number(b.dataset.avisoleido)}/leida`,{method:'PATCH'});await cargarAvisos31();}catch(e){avisoError31(e);}
    }));
  }catch(e){$31('lista-notificaciones').textContent=e.message;}
}

function opcionesEjerciciosAdmin31(){
  const select=$31('admin-ejercicio-existente');
  const selected=select.value;
  select.innerHTML='<option value="">Crear ejercicio nuevo</option>'+catalogoEjercicios.map(e=>`<option value="${Number(e.id_ejercicio)}">${esc(e.nombre)}</option>`).join('');
  if(catalogoEjercicios.some(e=>String(e.id_ejercicio)===selected))select.value=selected;
  $31('admin-ejercicio-grupo').innerHTML='<option value="">Selecciona un grupo</option>'+
      GRUPOS_IRONHUB.map(([id, nombre])=>`<option value="${id}">${esc(nombre)}</option>`).join('');
}
function seleccionarEditarEjercicio31(){
  const ej=catalogoEjercicios.find(e=>String(e.id_ejercicio)===$31('admin-ejercicio-existente').value);
  $31('admin-ejercicio-nombre').value=ej?.nombre||'';
  $31('admin-ejercicio-grupo').value=ej?String(ej.id_grupo):'';
  $31('admin-ejercicio-descripcion').value=ej?.descripcion||'';
  $31('admin-guardar-ejercicio').textContent=ej?'Guardar cambios':'Crear ejercicio';
}
async function guardarEjercicioAdmin31(ev){
  ev.preventDefault();
  const id=$31('admin-ejercicio-existente').value;
  const datos={nombre:$31('admin-ejercicio-nombre').value,
    id_grupo:Number($31('admin-ejercicio-grupo').value),
    descripcion:$31('admin-ejercicio-descripcion').value};
  const boton=$31('admin-guardar-ejercicio');boton.disabled=true;
  try{
    await apiFetch(id?`/admin/ejercicios/${Number(id)}`:'/ejercicios',{
      method:id?'PUT':'POST',body:JSON.stringify(datos)
    });
    mostrarToast(id?'Ejercicio actualizado.':'Ejercicio creado.');
    await cargarCatalogo();
    opcionesEjerciciosAdmin31();
    $31('admin-form-ejercicio').reset();seleccionarEditarEjercicio31();
    await cargarAdmin31();
  }catch(e){avisoError31(e);}finally{boton.disabled=false;}
}
function filtrarUsuarios31(){
  const q=$31('admin-buscar-cliente').value.trim().toLocaleLowerCase('es');
  const visibles=clientesAdmin31.filter(u=>`${u.nombre} ${u.apellido} ${u.email}`.toLocaleLowerCase('es').includes(q));
  $31('admin-usuarios').innerHTML=visibles.length?visibles.map(u=>`
    <div class="admin-usuario">
      <div><strong>${esc(u.nombre)} ${esc(u.apellido)}</strong><p>${esc(u.email)}</p>
        <small class="${u.activo?'estado-activo':'estado-inactivo'}">${u.activo?'Activo':'Inactivo'}</small></div>
      <button class="btn-mini ${u.activo?'peligro':''}" data-cambiaruser="${Number(u.id_usuario)}" data-estadousuario="${u.activo?'0':'1'}">${u.activo?'Desactivar':'Activar'}</button>
    </div>`).join(''):'<div class="empty-state">No se encontraron clientes.</div>';
  $31('admin-usuarios').querySelectorAll('[data-cambiaruser]').forEach(b=>b.addEventListener('click',()=>estadoUsuario31(b)));
}
async function estadoUsuario31(b){
  const activo=b.dataset.estadousuario==='1';
  if(!await confirmar(`¿Deseas ${activo?'activar':'desactivar'} esta cuenta de cliente?`,activo?'Activar':'Desactivar'))return;
  b.disabled=true;
  try{
    await apiFetch(`/admin/usuarios/${Number(b.dataset.cambiaruser)}/estado`,{method:'PATCH',body:JSON.stringify({activo})});
    mostrarToast('Estado del cliente actualizado.');await cargarAdmin31();
  }catch(e){avisoError31(e);}finally{b.disabled=false;}
}
async function cargarAdmin31(){
  if(Number(usuarioActual?.id_rol)!==1||cargandoAdmin31)return;
  cargandoAdmin31=true;
  try{
    const [res,usuarios,propuestas]=await Promise.all([
      apiFetch('/admin/resumen'), apiFetch('/admin/usuarios'), apiFetch('/propuestas/pendientes')
    ]);
    $31('admin-total-clientes').textContent=res.estadisticas.clientes;
    $31('admin-total-propuestas').textContent=res.estadisticas.propuestas;
    $31('admin-total-entrenos').textContent=res.estadisticas.entrenamientos;
    clientesAdmin31=usuarios.usuarios||[];filtrarUsuarios31();
    const pendientes=$31('admin-pendientes');
    pendientes.innerHTML=propuestas.propuestas?.length?propuestas.propuestas.map(p=>tarjetaPropuesta(p,true)).join(''):
      '<div class="empty-state">No hay propuestas pendientes. ¡Todo al día!</div>';
    pendientes.querySelectorAll('[data-revisar]').forEach(b=>b.addEventListener('click',async()=>{
      await revisarPropuesta(Number(b.dataset.revisar),b.dataset.decision);
      await cargarAdmin31();await cargarAvisos31();
    }));
    await renderMediaPropuestas(pendientes);
    opcionesEjerciciosAdmin31();
  }catch(e){avisoError31(e);}finally{cargandoAdmin31=false;}
}

// Conservar comportamiento original y activar módulos nuevos solo después de iniciar sesión.
const entrarAlPanelOriginal31=entrarAlPanel;
entrarAlPanel=async function(){
  await entrarAlPanelOriginal31();
  $31('tab-admin-boton').hidden=Number(usuarioActual?.id_rol)!==1;
  $31('entrenamiento-dia').value=String(new Date().getDay()||7);
  $31('filas-entrenamiento').innerHTML='';sumarFila31();
  if(Number(usuarioActual?.id_rol)===1) opcionesEjerciciosAdmin31();
  await cargarAvisos31();
};
const switchTabOriginal31=switchTab;
switchTab=function(tabId,btn){
  if(tabId==='tab-admin'&&Number(usuarioActual?.id_rol)!==1){mostrarToast('Acceso reservado a administradores.','error');return;}
  switchTabOriginal31(tabId,btn);
  if(tabId==='tab-progreso')cargarEntrenamientos31();
  if(tabId==='tab-perfil')cargarPerfil31();
  if(tabId==='tab-avisos')cargarAvisos31();
  if(tabId==='tab-admin')cargarAdmin31();
};
const cerrarSesionOriginal31=cerrarSesion;
cerrarSesion=function(silencioso){
  $31('tab-admin-boton').hidden=true;
  $31('lista-notificaciones').innerHTML='';
  $31('admin-usuarios').innerHTML='';
  clientesAdmin31=[];
  cerrarSesionOriginal31(silencioso);
};

document.addEventListener('DOMContentLoaded',()=>{
  $31('form-entrenamiento').addEventListener('submit',guardarEntrenamiento31);
  $31('agregar-fila-entreno').addEventListener('click',()=>sumarFila31());
  $31('cargar-entreno-dia').addEventListener('click',usarRutinaDelDia31);
  $31('form-perfil').addEventListener('submit',guardarPerfil31);
  $31('form-contrasena').addEventListener('submit',guardarClave31);
  $31('admin-actualizar').addEventListener('click',cargarAdmin31);
  $31('admin-buscar-cliente').addEventListener('input',filtrarUsuarios31);
  $31('admin-form-ejercicio').addEventListener('submit',guardarEjercicioAdmin31);
  $31('admin-ejercicio-existente').addEventListener('change',seleccionarEditarEjercicio31);
});
